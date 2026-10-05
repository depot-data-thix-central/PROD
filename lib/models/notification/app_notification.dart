// lib/models/notification/app_notification.dart
//
// ═══════════════════════════════════════════════════════════════════════════
// MODÈLE DE NOTIFICATION — aligné avec le schéma DB v2 (triggers + RPC)
// Champs exposés : id, user_id, sender_id, actor_id, type, category,
// entity_type, entity_id, title, body, route, priority, read, read_at,
// push_sent, data, created_at
//
// Utilise le catalogue centralisé (notification_catalog.dart) pour
// icône + couleur → cohérence totale hub / cloche / constellation.
// ═══════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:thix_id/services/notifications/notification_catalog.dart';

class AppNotification {
  // ── Identité ──
  final String id;
  final String userId;
  final String? senderId;
  final String? actorId;

  // ── Classification ──
  final String type;
  final String category; // 'network' | 'messages' | 'market' | 'money' | 'health' | 'media' | 'info' | 'system'
  final int priority;    // 0 = normal, 5+ = haute, 10 = critique (SOS)

  // ── Entité liée ──
  final String? entityType; // 'post', 'comment', 'order', 'document', 'chat', 'media', 'user', 'sos'
  final String? entityId;

  // ── Contenu ──
  final String title;
  final String body;
  final String? route; // Deep-link (ex: '/sos/alert/uuid', '/market/orders/uuid')

  // ── État ──
  final bool read;
  final DateTime? readAt;
  final bool pushSent;

  // ── Métadonnées (enrichies par triggers SQL) ──
  /// Contient : actor_name, actor_avatar, + payloads spécifiques (post_id, order_id, lat/lng SOS, etc.)
  final Map<String, dynamic> data;

  // ── Timestamp ──
  final DateTime? createdAt;

  const AppNotification({
    required this.id,
    required this.userId,
    this.senderId,
    this.actorId,
    required this.type,
    required this.category,
    this.priority = 0,
    this.entityType,
    this.entityId,
    required this.title,
    required this.body,
    this.route,
    required this.read,
    this.readAt,
    this.pushSent = false,
    required this.data,
    this.createdAt,
  });

  // ════════════════════════════════════════════════════════════════════════
  // FACTORY — depuis une ligne SQL (compatible anciennes + nouvelles notifs)
  // ════════════════════════════════════════════════════════════════════════
  factory AppNotification.fromMap(Map<String, dynamic> map) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is DateTime) return v;
      return DateTime.tryParse(v.toString());
    }

    int parsePriority(dynamic v) {
      if (v == null) return 0;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString()) ?? 0;
    }

    bool parseBool(dynamic v, {bool fallback = false}) {
      if (v == null) return fallback;
      if (v is bool) return v;
      if (v is num) return v != 0;
      final s = v.toString().toLowerCase();
      return s == 'true' || s == '1' || s == 'yes';
    }

    Map<String, dynamic> parseData(dynamic v) {
      if (v is Map) return Map<String, dynamic>.from(v);
      return const <String, dynamic>{};
    }

    final data = parseData(map['data']);

    // Catégorie : prioriser la colonne `category`, sinon dériver depuis le catalogue
    final rawCategory = (map['category']?.toString().trim() ?? '').toLowerCase();
    final type = (map['type']?.toString() ?? 'generic').toLowerCase();
    final category = rawCategory.isNotEmpty
        ? rawCategory
        : (notifMeta(type).category.isEmpty ? 'system' : notifMeta(type).category);

    // Route : sanitization défensive (bloquer les schémas externes)
    String? parseRoute(dynamic v) {
      if (v == null) return null;
      final s = v.toString().trim();
      if (s.isEmpty || !s.startsWith('/')) return null;
      if (s.contains('..') || s.contains('javascript:') || s.contains('://')) return null;
      return s;
    }

    return AppNotification(
      id: (map['id'] ?? '').toString(),
      userId: (map['user_id'] ?? '').toString(),
      senderId: map['sender_id']?.toString(),
      actorId: map['actor_id']?.toString() ?? map['sender_id']?.toString(),
      type: type,
      category: category,
      priority: parsePriority(map['priority']).clamp(0, 10),
      entityType: map['entity_type']?.toString(),
      entityId: map['entity_id']?.toString(),
      title: (map['title'] ?? 'THIX ID').toString(),
      body: (map['body'] ?? map['content'] ?? '').toString(),
      route: parseRoute(map['route']),
      // Compatibilité : is_read (nouveau) puis read (legacy)
      read: parseBool(map['is_read'] ?? map['read']),
      readAt: parseDate(map['read_at']),
      pushSent: parseBool(map['push_sent']),
      data: data,
      createdAt: parseDate(map['created_at']),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  // CATALOGUE CENTRALISÉ — icône + couleur cohérents avec le hub
  // ════════════════════════════════════════════════════════════════════════

  /// Métadonnées visuelles (icône + couleur + catégorie) depuis le catalogue.
  /// Fallback sur 'generic' si le type n'est pas dans le catalogue.
  NotifMeta get meta => notifMeta(type);

  /// Icône à afficher pour cette notification.
  IconData get icon => meta.icon;

  /// Couleur d'accent pour cette notification.
  Color get color => meta.color;

  /// Catégorie normalisée (toujours non vide).
  String get normalizedCategory => category.isEmpty ? 'system' : category;

  // ════════════════════════════════════════════════════════════════════════
  // HELPERS D'AFFICHAGE
  // ════════════════════════════════════════════════════════════════════════

  /// Nom de l'acteur (expéditeur enrichi par les triggers SQL).
  String? get actorName => data['actor_name']?.toString();

  /// Avatar de l'acteur (URL enrichie par les triggers SQL).
  String? get actorAvatar {
    final v = data['actor_avatar']?.toString();
    if (v == null || v.isEmpty) return null;
    if (!v.startsWith('http')) return null;
    return v;
  }

  /// Titre enrichi : "Nom • Titre" si l'acteur est connu, sinon juste le titre.
  String get displayTitle {
    final name = actorName;
    if (name == null || name.isEmpty) return title;
    return '$name • $title';
  }

  /// Indique si la notification est de haute priorité (badge pulsant, push urgent).
  bool get isHighPriority => priority >= 5;

  /// Indique si la notification est critique (SOS, paiements urgents).
  bool get isCritical => priority >= 10;

  /// Indique si la notification concerne une urgence santé (SOS).
  bool get isSosAlert => type == 'sos' || category == 'health' && priority >= 5;

  // ════════════════════════════════════════════════════════════════════════
  // HELPERS DE TEMPS
  // ════════════════════════════════════════════════════════════════════════

  /// Temps écoulé depuis la création (pour "il y a 5 min").
  Duration? get age {
    if (createdAt == null) return null;
    return DateTime.now().difference(createdAt!);
  }

  /// Indique si la notification est récente (< 2 min) — utilisé pour
  /// éviter les pop sur des notifications anciennes.
  bool get isRecent {
    final a = age;
    if (a == null) return false;
    return a.inMinutes < 2;
  }

  /// Libellé humain du temps écoulé.
  String timeAgo({String locale = 'fr'}) {
    final a = age;
    if (a == null) return '';
    if (a.inSeconds < 60) return locale == 'fr' ? "à l'instant" : 'just now';
    if (a.inMinutes < 60) {
      final m = a.inMinutes;
      return locale == 'fr' ? 'il y a $m min' : '$m min ago';
    }
    if (a.inHours < 24) {
      final h = a.inHours;
      return locale == 'fr' ? 'il y a $h h' : '$h h ago';
    }
    final d = a.inDays;
    return locale == 'fr' ? 'il y a $d j' : '$d d ago';
  }

  // ════════════════════════════════════════════════════════════════════════
  // HELPERS DE ROUTE (deep-link)
  // ════════════════════════════════════════════════════════════════════════

  /// Route complète pour navigation. Si absente, construit une route
  /// générique basée sur l'entité (post, order, etc.).
  String? get deepLink {
    if (route != null && route!.isNotEmpty) return route;
    if (entityType == null || entityId == null) return null;
    switch (entityType) {
      case 'post': return '/network/post/$entityId';
      case 'comment': return '/network/comment/$entityId';
      case 'order': return '/market/orders/$entityId';
      case 'document': return '/vault';
      case 'chat': return '/chat/$entityId';
      case 'media': return '/media/$entityId';
      case 'user': return '/profile/$entityId';
      case 'sos': return '/sos/alert/$entityId';
      default: return null;
    }
  }

  /// Indique si la notification a une route de deep-link utilisable.
  bool get hasDeepLink => deepLink != null && deepLink!.isNotEmpty;

  // ════════════════════════════════════════════════════════════════════════
  // HELPERS MÉTIER (legacy compatibility + nouveaux types)
  // ════════════════════════════════════════════════════════════════════════

  /// Clé d'icône legacy (pour le code existant qui n'utilise pas le catalogue).
  /// ⚠️ Préférer [icon] et [color] directement.
  String get iconKey {
    switch (category) {
      case 'messages': return 'chat';
      case 'money': return 'money';
      case 'media': return 'live';
      case 'network': return 'live';
      case 'jobs':
      case 'opportunities': return 'opportunity';
      case 'events': return 'event';
      case 'health': return 'health';
      case 'market': return 'market';
      default: return 'generic';
    }
  }

  /// Indique si la notification concerne une interaction sociale.
  bool get isSocialInteraction => const {
    'like', 'comment', 'comment_like', 'comment_reply',
    'repost', 'follow', 'friend_request', 'friend_accepted',
    'mention', 'tag', 'media_like', 'media_comment', 'media_reply',
  }.contains(type);

  /// Indique si la notification concerne une transaction commerciale.
  bool get isCommerceInteraction => const {
    'order_new', 'order_status', 'payment_received',
    'refund_requested', 'refund_processed', 'payout_released',
  }.contains(type);

  /// Indique si la notification est liée à un appel vocal/vidéo.
  bool get isCallInteraction => const {'call', 'call_missed', 'call_ended'}.contains(type);

  // ════════════════════════════════════════════════════════════════════════
  // COPY / EQUALS / TOSTRING
  // ════════════════════════════════════════════════════════════════════════

  /// Crée une copie avec `read = true` (pour usage après markAsRead).
  AppNotification copyAsRead() => AppNotification(
    id: id,
    userId: userId,
    senderId: senderId,
    actorId: actorId,
    type: type,
    category: category,
    priority: priority,
    entityType: entityType,
    entityId: entityId,
    title: title,
    body: body,
    route: route,
    read: true,
    readAt: DateTime.now(),
    pushSent: pushSent,
    data: data,
    createdAt: createdAt,
  );

  @override
  bool operator ==(Object other) =>
      other is AppNotification && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'AppNotification(id: ${id.substring(0, id.length.clamp(0, 8))}, '
      'type: $type, category: $category, priority: $priority, read: $read, '
      'title: "$title")';
}
