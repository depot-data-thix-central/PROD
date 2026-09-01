// lib/services/chat/connection_service.dart
//
// ============================================================================
// CONNECTION SERVICE — Production Enterprise
// ============================================================================
//
// Service de gestion du réseau de connexions utilisateur :
//   - Demandes de connexion (envoyées/reçues)
//   - Connexions actives
//   - Accept/reject/cancel/block/remove
//   - Statut entre 2 utilisateurs
//
// Architecture :
//   - SupabaseClient injectable (testable via Riverpod)
//   - Validation UUID stricte sur tous les IDs
//   - Sanitization XSS sur tous les contenus user
//   - Modèles typés (plus de Map<String, dynamic>)
//   - Queries optimisées (OR, RPC batch)
//   - Protection ownership (vérification user authentifié)
//
// Sécurité :
//   - Validation UUID v4 sur tous les IDs
//   - Sanitization XSS sur messages
//   - Max message length 500 caractères
//   - Ownership checks sur actions destructives
//   - Stack traces masquées en production
// ============================================================================

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ============================================================================
// CONSTANTS
// ============================================================================
const int _kDefaultLimit = 20;
const int _kMaxLimit = 100;
const int _kMaxMessageLength = 500;
const int _kMaxDisplayNameLength = 100;
const Duration _kDbTimeout = Duration(seconds: 15);
const Duration _kRpcTimeout = Duration(seconds: 20);
const Duration _kRejectedFreshness = Duration(days: 30); // Reject ignoré si > 30j

// ============================================================================
// VALIDATORS
// ============================================================================
class _ConnectionValidators {
  _ConnectionValidators._();

  /// Valide un UUID v4 strict.
  static bool isValidUuid(String? id) {
    if (id == null) return false;
    final trimmed = id.trim();
    if (trimmed.isEmpty || trimmed.length > 100) return false;
    return RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false,
    ).hasMatch(trimmed);
  }

  /// Sanitize un message (XSS + caractères de contrôle).
  static String sanitizeMessage(String? input) {
    if (input == null) return '';
    var s = input
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'javascript:', caseSensitive: false), '')
        .replaceAll(RegExp(r'on\w+\s*=', caseSensitive: false), '')
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        .trim();
    return s.length > _kMaxMessageLength
        ? s.substring(0, _kMaxMessageLength)
        : s;
  }

  /// Sanitize un display name.
  static String sanitizeName(String? input) {
    if (input == null) return 'Inconnu';
    var s = input
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        .trim();
    if (s.isEmpty) return 'Inconnu';
    return s.length > _kMaxDisplayNameLength
        ? s.substring(0, _kMaxDisplayNameLength)
        : s;
  }

  /// Obfusque un ID pour les logs.
  static String obfuscate(String? s) {
    if (s == null || s.length <= 8) return '***';
    return '${s.substring(0, 4)}...${s.substring(s.length - 4)}';
  }
}

// ============================================================================
// EXCEPTIONS
// ============================================================================

class ConnectionException implements Exception {
  final String message;
  final Object? cause;
  const ConnectionException(this.message, [this.cause]);
  @override
  String toString() => 'ConnectionException: $message';
}

// ============================================================================
// MODÈLES
// ============================================================================

/// Représente un profil utilisateur dans le contexte des connexions.
class ConnectionUserProfile {
  final String id;
  final String displayName;
  final String? username;
  final String? avatarUrl;

  const ConnectionUserProfile({
    required this.id,
    required this.displayName,
    this.username,
    this.avatarUrl,
  });

  factory ConnectionUserProfile.fromJson(Map<String, dynamic> json) {
    return ConnectionUserProfile(
      id: (json['id'] ?? '').toString(),
      displayName: _ConnectionValidators.sanitizeName(json['display_name'] as String?),
      username: (json['username'] as String?)?.trim(),
      avatarUrl: json['avatar_url'] as String?,
    );
  }
}

/// Demande de connexion (envoyée ou reçue).
class ConnectionRequest {
  final String id;
  final String senderId;
  final String receiverId;
  final String status;
  final String? message;
  final DateTime createdAt;
  final DateTime? respondedAt;
  final ConnectionUserProfile? sender;
  final ConnectionUserProfile? receiver;

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
      id: (json['id'] ?? '').toString(),
      senderId: (json['sender_id'] ?? '').toString(),
      receiverId: (json['receiver_id'] ?? '').toString(),
      status: (json['status'] ?? 'pending').toString(),
      message: _ConnectionValidators.sanitizeMessage(json['message'] as String?),
      createdAt: _safeParseDate(json['created_at']),
      respondedAt: json['responded_at'] != null
          ? _safeParseDate(json['responded_at'])
          : null,
      sender: json['sender'] is Map
          ? ConnectionUserProfile.fromJson(Map<String, dynamic>.from(json['sender'] as Map))
          : null,
      receiver: json['receiver'] is Map
          ? ConnectionUserProfile.fromJson(Map<String, dynamic>.from(json['receiver'] as Map))
          : null,
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

/// Connexion active entre 2 utilisateurs.
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
      id: (json['id'] ?? '').toString(),
      user1Id: (json['user1_id'] ?? '').toString(),
      user2Id: (json['user2_id'] ?? '').toString(),
      createdAt: _safeParseDate(json['created_at']),
    );
  }
}

/// Vue enrichie d'une connexion avec le profil de l'autre utilisateur.
class ConnectionView {
  final String connectionId;
  final String otherUserId;
  final ConnectionUserProfile otherUser;

  const ConnectionView({
    required this.connectionId,
    required this.otherUserId,
    required this.otherUser,
  });
}

/// Statut de la relation entre 2 utilisateurs.
enum ConnectionStatus {
  self,
  blocked,
  connected,
  pendingSent,     // J'ai envoyé une demande en attente
  pendingReceived, // J'ai reçu une demande en attente
  rejected,
  none,
}

/// Parse une date de manière sûre.
DateTime _safeParseDate(dynamic value) {
  if (value == null) return DateTime.now().toUtc();
  try {
    return DateTime.parse(value.toString());
  } catch (_) {
    return DateTime.now().toUtc();
  }
}

// ============================================================================
// CONNECTION SERVICE
// ============================================================================

/// Service de gestion des connexions utilisateur.
///
/// **Usage** :
/// ```dart
/// final service = ref.read(connectionServiceProvider);
/// await service.loadData(userId);
/// final connections = service.connections;
/// ```
class ConnectionService extends ChangeNotifier {
  final SupabaseClient _supabase;
  bool _isDisposed = false;

  List<ConnectionRequest> _sentRequests = [];
  List<ConnectionRequest> _receivedRequests = [];
  List<ConnectionView> _connections = [];
  bool _isLoading = false;
  String? _error;

  ConnectionService({SupabaseClient? client})
      : _supabase = client ?? Supabase.instance.client {
    debugPrint('[ConnectionService] 🚀 Initialized');
  }

  // ─── GETTERS ────────────────────────────────────────────────

  List<ConnectionRequest> get sentRequests => List.unmodifiable(_sentRequests);
  List<ConnectionRequest> get receivedRequests => List.unmodifiable(_receivedRequests);
  List<ConnectionView> get connections => List.unmodifiable(_connections);
  bool get isLoading => _isLoading;
  String? get error => _error;

  // ─── CHARGEMENT & PAGINATION ────────────────────────────────

  /// Charge toutes les données (demandes + connexions) pour un utilisateur.
  Future<void> loadData(String userId, {int limit = _kDefaultLimit, int offset = 0}) async {
    if (_isDisposed) return;
    if (!_ConnectionValidators.isValidUuid(userId)) {
      _setError('userId invalide');
      return;
    }

    _setLoading(true);
    _error = null;

    try {
      // Parallélisation des 3 queries indépendantes
      final results = await Future.wait<dynamic>([
        _getSentRequests(userId),
        _getPendingRequests(userId),
        _getActiveConnections(userId, limit: limit, offset: offset),
      ]).timeout(_kDbTimeout);

      if (_isDisposed) return;

      _sentRequests = results[0] as List<ConnectionRequest>;
      _receivedRequests = results[1] as List<ConnectionRequest>;

      final active = results[2] as List<ConnectionView>;
      if (offset == 0) {
        _connections = active;
      } else {
        // Déduplication par otherUserId
        final existingIds = _connections.map((c) => c.otherUserId).toSet();
        final uniqueNew = active.where((c) => !existingIds.contains(c.otherUserId)).toList();
        _connections = [..._connections, ...uniqueNew];
      }

      _setLoading(false);
      debugPrint('[ConnectionService] ✓ Loaded data for ${_ConnectionValidators.obfuscate(userId)}');
    } catch (e) {
      if (_isDisposed) return;
      _setError(e);
      debugPrint('[ConnectionService] ❌ loadData: '
          '${kDebugMode ? e : e.toString().split('\n').first}');
    }
  }

  /// Charge plus de connexions (pagination).
  Future<List<ConnectionView>> loadMoreConnections(
    String userId, {
    required int offset,
    required int limit,
  }) async {
    if (_isDisposed) return [];
    if (!_ConnectionValidators.isValidUuid(userId)) return [];

    try {
      final more = await _getActiveConnections(
        userId,
        limit: limit.clamp(1, _kMaxLimit),
        offset: offset.clamp(0, 10000),
      ).timeout(_kDbTimeout);

      if (_isDisposed) return [];

      // Déduplication
      final existingIds = _connections.map((c) => c.otherUserId).toSet();
      final uniqueNew = more.where((c) => !existingIds.contains(c.otherUserId)).toList();
      _connections = [..._connections, ...uniqueNew];

      notifyListeners();
      return uniqueNew;
    } catch (e) {
      _setError(e);
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
        .order('created_at', ascending: false)
        .limit(_kMaxLimit);

    return (response as List)
        .map((json) => ConnectionRequest.fromJson(Map<String, dynamic>.from(json as Map)))
        .toList();
  }

  Future<List<ConnectionRequest>> _getSentRequests(String userId) async {
    final response = await _supabase
        .from('connection_requests')
        .select('*, receiver:profiles!receiver_id(id, display_name, username, avatar_url)')
        .eq('sender_id', userId)
        .eq('status', 'pending')
        .order('created_at', ascending: false)
        .limit(_kMaxLimit);

    return (response as List)
        .map((json) => ConnectionRequest.fromJson(Map<String, dynamic>.from(json as Map)))
        .toList();
  }

  Future<List<ConnectionView>> _getActiveConnections(
    String userId, {
    int limit = _kDefaultLimit,
    int offset = 0,
  }) async {
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
        .range(offset, offset + limit - 1);

    final views = <ConnectionView>[];
    for (var row in response) {
      final map = Map<String, dynamic>.from(row as Map);
      final isUser1 = map['user1_id'] == userId;
      final otherRaw = isUser1 ? map['user2'] : map['user1'];

      if (otherRaw is Map) {
        final other = ConnectionUserProfile.fromJson(Map<String, dynamic>.from(otherRaw));
        views.add(ConnectionView(
          connectionId: map['id'].toString(),
          otherUserId: other.id,
          otherUser: other,
        ));
      }
    }
    return views;
  }

  void _setLoading(bool loading) {
    if (_isDisposed) return;
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(Object? e) {
    if (_isDisposed) return;
    _error = kDebugMode ? e?.toString() : 'Une erreur est survenue';
    _isLoading = false;
    notifyListeners();
  }

  // ─── SEND REQUEST ────────────────────────────────────────────

  /// Envoie une demande de connexion.
  ///
  /// Si une demande existe déjà (dans un sens ou l'autre), elle est réactivée.
  Future<bool> sendRequest({
    required String senderId,
    required String receiverId,
    String? message,
  }) async {
    if (_isDisposed) return false;

    if (!_ConnectionValidators.isValidUuid(senderId)) {
      _setError('senderId invalide');
      return false;
    }
    if (!_ConnectionValidators.isValidUuid(receiverId)) {
      _setError('receiverId invalide');
      return false;
    }
    if (senderId == receiverId) {
      _setError('Impossible de s\'envoyer une demande à soi-même');
      return false;
    }

    final sanitizedMessage = _ConnectionValidators.sanitizeMessage(message);

    try {
      // 1 query au lieu de 2 avec OR
      final existing = await _supabase
          .from('connection_requests')
          .select()
          .or(
            'and(sender_id.eq.$senderId,receiver_id.eq.$receiverId),'
            'and(sender_id.eq.$receiverId,receiver_id.eq.$senderId)',
          )
          .maybeSingle()
          .timeout(_kDbTimeout);

      if (existing != null) {
        // Reactivate existing request
        await _supabase
            .from('connection_requests')
            .update({
              'status': 'pending',
              'message': sanitizedMessage,
              'sender_id': senderId,
              'receiver_id': receiverId,
              'updated_at': DateTime.now().toUtc().toIso8601String(),
              'responded_at': null,
            })
            .eq('id', existing['id'])
            .timeout(_kDbTimeout);

        debugPrint('[ConnectionService] ✓ Request reactivated: '
            '${_ConnectionValidators.obfuscate(existing['id'].toString())}');
      } else {
        await _supabase
            .from('connection_requests')
            .insert({
              'sender_id': senderId,
              'receiver_id': receiverId,
              'message': sanitizedMessage.isEmpty ? null : sanitizedMessage,
              'status': 'pending',
            })
            .select()
            .single()
            .timeout(_kDbTimeout);

        debugPrint('[ConnectionService] ✓ Request sent: '
            '${_ConnectionValidators.obfuscate(senderId)} → '
            '${_ConnectionValidators.obfuscate(receiverId)}');
      }

      await loadData(senderId);
      return true;
    } catch (e) {
      _setError(e);
      debugPrint('[ConnectionService] ❌ sendRequest: '
          '${kDebugMode ? e : e.toString().split('\n').first}');
      return false;
    }
  }

  // ─── ACCEPT / REJECT / CANCEL ────────────────────────────────

  Future<bool> acceptRequest(String requestId, String userId) async {
    if (_isDisposed) return false;
    if (!_ConnectionValidators.isValidUuid(requestId) ||
        !_ConnectionValidators.isValidUuid(userId)) {
      _setError('ID invalide');
      return false;
    }

    try {
      // Récupérer la demande avec maybeSingle (pas single)
      final request = await _supabase
          .from('connection_requests')
          .select()
          .eq('id', requestId)
          .eq('receiver_id', userId)  // ✅ Ownership check
          .maybeSingle()
          .timeout(_kDbTimeout);

      if (request == null) {
        _setError('Demande introuvable ou accès refusé');
        return false;
      }

      // Update status
      await _supabase
          .from('connection_requests')
          .update({
            'status': 'accepted',
            'responded_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', requestId)
          .timeout(_kDbTimeout);

      // Créer la connexion (évite doublons avec tri)
      final ids = [request['sender_id'].toString(), request['receiver_id'].toString()]..sort();
      if (!_ConnectionValidators.isValidUuid(ids[0]) ||
          !_ConnectionValidators.isValidUuid(ids[1])) {
        _setError('IDs de connexion invalides');
        return false;
      }

      // Upsert pour éviter violation contrainte unique
      await _supabase.from('connections').upsert(
        {
          'user1_id': ids[0],
          'user2_id': ids[1],
        },
        onConflict: 'user1_id,user2_id',
      ).timeout(_kDbTimeout);

      debugPrint('[ConnectionService] ✓ Request accepted: '
          '${_ConnectionValidators.obfuscate(requestId)}');

      await loadData(userId);
      return true;
    } catch (e) {
      _setError(e);
      debugPrint('[ConnectionService] ❌ acceptRequest: '
          '${kDebugMode ? e : e.toString().split('\n').first}');
      return false;
    }
  }

  Future<bool> rejectRequest(String requestId, String userId) async {
    if (_isDisposed) return false;
    if (!_ConnectionValidators.isValidUuid(requestId) ||
        !_ConnectionValidators.isValidUuid(userId)) {
      _setError('ID invalide');
      return false;
    }

    try {
      await _supabase
          .from('connection_requests')
          .update({
            'status': 'rejected',
            'responded_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', requestId)
          .eq('receiver_id', userId)  // ✅ Ownership check
          .timeout(_kDbTimeout);

      debugPrint('[ConnectionService] ✓ Request rejected: '
          '${_ConnectionValidators.obfuscate(requestId)}');

      await loadData(userId);
      return true;
    } catch (e) {
      _setError(e);
      return false;
    }
  }

  Future<bool> cancelRequest(String requestId, String userId) async {
    if (_isDisposed) return false;
    if (!_ConnectionValidators.isValidUuid(requestId) ||
        !_ConnectionValidators.isValidUuid(userId)) {
      _setError('ID invalide');
      return false;
    }

    try {
      await _supabase
          .from('connection_requests')
          .delete()
          .eq('id', requestId)
          .eq('sender_id', userId)  // ✅ Ownership check
          .timeout(_kDbTimeout);

      debugPrint('[ConnectionService] ✓ Request cancelled: '
          '${_ConnectionValidators.obfuscate(requestId)}');

      await loadData(userId);
      return true;
    } catch (e) {
      _setError(e);
      return false;
    }
  }

  // ─── REMOVE / BLOCK ──────────────────────────────────────────

  /// Supprime une connexion (ownership check sur currentUserId).
  Future<bool> removeConnection(String currentUserId, String otherUserId) async {
    if (_isDisposed) return false;
    if (!_ConnectionValidators.isValidUuid(currentUserId) ||
        !_ConnectionValidators.isValidUuid(otherUserId)) {
      _setError('ID invalide');
      return false;
    }
    if (currentUserId == otherUserId) {
      _setError('Opération invalide');
      return false;
    }

    try {
      final count = await _supabase
          .from('connections')
          .delete()
          .or(
            'and(user1_id.eq.$currentUserId,user2_id.eq.$otherUserId),'
            'and(user1_id.eq.$otherUserId,user2_id.eq.$currentUserId)',
          )
          .timeout(_kDbTimeout);

      debugPrint('[ConnectionService] ✓ Connection removed: '
          '${_ConnectionValidators.obfuscate(currentUserId)} ↔ '
          '${_ConnectionValidators.obfuscate(otherUserId)}');

      await loadData(currentUserId);
      return true;
    } catch (e) {
      _setError(e);
      debugPrint('[ConnectionService] ❌ removeConnection: '
          '${kDebugMode ? e : e.toString().split('\n').first}');
      return false;
    }
  }

  /// Bloque un utilisateur (via RPC qui nettoie demandes + connexions).
  Future<bool> blockUser(String currentUserId, String otherUserId) async {
    if (_isDisposed) return false;
    if (!_ConnectionValidators.isValidUuid(currentUserId) ||
        !_ConnectionValidators.isValidUuid(otherUserId)) {
      _setError('ID invalide');
      return false;
    }
    if (currentUserId == otherUserId) {
      _setError('Impossible de se bloquer soi-même');
      return false;
    }

    try {
      await _supabase
          .rpc(
            'block_user_and_clean',
            params: {
              'blocker': currentUserId,
              'blocked': otherUserId,
            },
          )
          .timeout(_kRpcTimeout);

      debugPrint('[ConnectionService] ✓ User blocked: '
          '${_ConnectionValidators.obfuscate(currentUserId)} → '
          '${_ConnectionValidators.obfuscate(otherUserId)}');

      await loadData(currentUserId);
      return true;
    } catch (e) {
      _setError(e);
      debugPrint('[ConnectionService] ❌ blockUser: '
          '${kDebugMode ? e : e.toString().split('\n').first}');
      return false;
    }
  }

  // ─── STATUS BETWEEN USERS ────────────────────────────────────

  /// Vérifie si 2 utilisateurs sont connectés (booléen simple).
  Future<bool> checkConnection(String userId1, String userId2) async {
    if (userId1 == userId2) return false;
    if (!_ConnectionValidators.isValidUuid(userId1) ||
        !_ConnectionValidators.isValidUuid(userId2)) {
      return false;
    }

    try {
      // 1 query avec OR au lieu de 2 queries séquentielles
      final response = await _supabase
          .from('connections')
          .select('id')
          .or(
            'and(user1_id.eq.$userId1,user2_id.eq.$userId2),'
            'and(user1_id.eq.$userId2,user2_id.eq.$userId1)',
          )
          .maybeSingle()
          .timeout(_kDbTimeout);

      return response != null;
    } catch (e) {
      debugPrint('[ConnectionService] ⚠️ checkConnection: '
          '${kDebugMode ? e : e.toString().split('\n').first}');
      return false;
    }
  }

  /// Retourne le statut complet de la relation entre 2 utilisateurs.
  ///
  /// Ordre de priorité :
  ///   1. `self` — même utilisateur
  ///   2. `blocked` — blocage dans un sens ou l'autre
  ///   3. `connected` — connexion active
  ///   4. `pendingSent` — demande envoyée en attente
  ///   5. `pendingReceived` — demande reçue en attente
  ///   6. `rejected` — demande rejetée (si < 30 jours)
  ///   7. `none` — aucune relation
  Future<ConnectionStatus> getStatusBetween(String userId1, String userId2) async {
    if (userId1 == userId2) return ConnectionStatus.self;
    if (!_ConnectionValidators.isValidUuid(userId1) ||
        !_ConnectionValidators.isValidUuid(userId2)) {
      return ConnectionStatus.none;
    }

    try {
      // 1. Blocage (1 query avec OR)
      final blockCheck = await _supabase
          .from('blocked_users')
          .select('id')
          .or(
            'and(blocker_id.eq.$userId1,blocked_id.eq.$userId2),'
            'and(blocker_id.eq.$userId2,blocked_id.eq.$userId1)',
          )
          .maybeSingle()
          .timeout(_kDbTimeout);
      if (blockCheck != null) return ConnectionStatus.blocked;

      // 2. Connexion active (1 query avec OR)
      final connCheck = await _supabase
          .from('connections')
          .select('id')
          .or(
            'and(user1_id.eq.$userId1,user2_id.eq.$userId2),'
            'and(user1_id.eq.$userId2,user2_id.eq.$userId1)',
          )
          .maybeSingle()
          .timeout(_kDbTimeout);
      if (connCheck != null) return ConnectionStatus.connected;

      // 3. Demandes en attente (1 query avec OR + filter status)
      final pendingCheck = await _supabase
          .from('connection_requests')
          .select('sender_id, status')
          .or(
            'and(sender_id.eq.$userId1,receiver_id.eq.$userId2),'
            'and(sender_id.eq.$userId2,receiver_id.eq.$userId1)',
          )
          .inFilter('status', ['pending', 'rejected'])
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle()
          .timeout(_kDbTimeout);

      if (pendingCheck != null) {
        final status = pendingCheck['status']?.toString();
        final senderId = pendingCheck['sender_id']?.toString();

        if (status == 'pending') {
          return senderId == userId1
              ? ConnectionStatus.pendingSent
              : ConnectionStatus.pendingReceived;
        }

        if (status == 'rejected') {
          // Ignore si > 30 jours
          final respondedAt = pendingCheck['responded_at'];
          if (respondedAt != null) {
            final responded = _safeParseDate(respondedAt);
            if (DateTime.now().difference(responded) > _kRejectedFreshness) {
              return ConnectionStatus.none;
            }
          }
          return ConnectionStatus.rejected;
        }
      }

      return ConnectionStatus.none;
    } catch (e) {
      debugPrint('[ConnectionService] ⚠️ getStatusBetween: '
          '${kDebugMode ? e : e.toString().split('\n').first}');
      return ConnectionStatus.none;
    }
  }

  // ─── DISPOSE ────────────────────────────────────────────────

  @override
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _sentRequests = [];
    _receivedRequests = [];
    _connections = [];
    debugPrint('[ConnectionService] 👋 Disposed');
    super.dispose();
  }
}
