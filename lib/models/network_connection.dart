// lib/models/network_connection.dart
import 'package:flutter/material.dart';

class NetworkConnection {
  final String id;
  final String name;
  final String? avatar;
  final String title;
  final int mutualConnections;
  final String? status;
  final DateTime? connectedAt;

  NetworkConnection({
    required this.id,
    required this.name,
    this.avatar,
    required this.title,
    required this.mutualConnections,
    this.status,
    this.connectedAt,
  });

  // Constructeur vide pour les tests
  NetworkConnection.empty()
      : id = '',
        name = '',
        avatar = null,
        title = '',
        mutualConnections = 0,
        status = null,
        connectedAt = null;

  // Getters
  bool get isConnected => status == 'accepted';
  bool get isPending => status == 'pending';
  bool get isRejected => status == 'rejected';
  bool get hasAvatar => avatar != null && avatar!.isNotEmpty;
  bool get isValid => id.isNotEmpty && name.isNotEmpty;
  
  String get initials => name.isNotEmpty ? name[0].toUpperCase() : '?';
  
  String get avatarUrl => hasAvatar ? avatar! : '';
  
  String get formattedMutualConnections {
    if (mutualConnections == 0) return 'Aucune connexion commune';
    if (mutualConnections == 1) return '1 connexion commune';
    return '$mutualConnections connexions communes';
  }
  
  String get connectionDate {
    if (connectedAt == null) return '';
    return 'Connecté le ${_formatDate(connectedAt!)}';
  }
  
  String get statusLabel {
    switch (status) {
      case 'accepted':
        return 'Connecté';
      case 'pending':
        return 'En attente';
      case 'rejected':
        return 'Refusé';
      default:
        return '';
    }
  }
  
  Color get statusColor {
    switch (status) {
      case 'accepted':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';

  factory NetworkConnection.fromJson(Map<String, dynamic> json) {
    return NetworkConnection(
      id: json['id']?.toString() ?? '',
      name: json['display_name']?.toString() ?? json['name']?.toString() ?? 'Utilisateur',
      avatar: json['avatar_url']?.toString() ?? json['avatar']?.toString(),
      title: json['title']?.toString() ?? 'Membre THIX',
      mutualConnections: (json['mutual_connections'] as int?) ?? (json['mutualConnections'] as int?) ?? 0,
      status: json['status']?.toString(),
      connectedAt: json['connected_at'] != null 
          ? DateTime.tryParse(json['connected_at'] as String) 
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'display_name': name,
    'avatar_url': avatar,
    'title': title,
    'mutual_connections': mutualConnections,
    'status': status,
    'connected_at': connectedAt?.toIso8601String(),
  };

  NetworkConnection copyWith({
    String? id,
    String? name,
    String? avatar,
    String? title,
    int? mutualConnections,
    String? status,
    DateTime? connectedAt,
  }) {
    return NetworkConnection(
      id: id ?? this.id,
      name: name ?? this.name,
      avatar: avatar ?? this.avatar,
      title: title ?? this.title,
      mutualConnections: mutualConnections ?? this.mutualConnections,
      status: status ?? this.status,
      connectedAt: connectedAt ?? this.connectedAt,
    );
  }

  @override
  String toString() => 'NetworkConnection(id: $id, name: $name, status: $status)';
}

class ConnectionRequest {
  final String id;
  final String requesterId;
  final String requesterName;
  final String? requesterAvatar;
  final String requesterTitle;
  final DateTime createdAt;

  ConnectionRequest({
    required this.id,
    required this.requesterId,
    required this.requesterName,
    this.requesterAvatar,
    required this.requesterTitle,
    required this.createdAt,
  });

  // Constructeur vide pour les tests
  ConnectionRequest.empty()
      : id = '',
        requesterId = '',
        requesterName = '',
        requesterAvatar = null,
        requesterTitle = '',
        createdAt = DateTime.now();

  // Getters
  bool get hasAvatar => requesterAvatar != null && requesterAvatar!.isNotEmpty;
  String get avatarUrl => hasAvatar ? requesterAvatar! : '';
  String get initials => requesterName.isNotEmpty ? requesterName[0].toUpperCase() : '?';
  
  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inDays > 7) return 'il y a plus d\'une semaine';
    if (diff.inDays > 0) return 'il y a ${diff.inDays} jour${diff.inDays > 1 ? 's' : ''}';
    if (diff.inHours > 0) return 'il y a ${diff.inHours} heure${diff.inHours > 1 ? 's' : ''}';
    if (diff.inMinutes > 0) return 'il y a ${diff.inMinutes} minute${diff.inMinutes > 1 ? 's' : ''}';
    return 'à l\'instant';
  }
  
  String get formattedDate {
    return '${createdAt.day}/${createdAt.month}/${createdAt.year} à ${createdAt.hour}:${createdAt.minute.toString().padLeft(2, '0')}';
  }

  factory ConnectionRequest.fromJson(Map<String, dynamic> json) {
    final requester = json['requester'] as Map<String, dynamic>?;
    
    return ConnectionRequest(
      id: json['id']?.toString() ?? '',
      requesterId: requester?['id']?.toString() ?? json['requester_id']?.toString() ?? '',
      requesterName: requester?['display_name']?.toString() ?? 'Utilisateur',
      requesterAvatar: requester?['avatar_url']?.toString(),
      requesterTitle: requester?['title']?.toString() ?? 'Membre THIX',
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String) 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'requester_id': requesterId,
    'requester_name': requesterName,
    'requester_avatar': requesterAvatar,
    'requester_title': requesterTitle,
    'created_at': createdAt.toIso8601String(),
  };

  ConnectionRequest copyWith({
    String? id,
    String? requesterId,
    String? requesterName,
    String? requesterAvatar,
    String? requesterTitle,
    DateTime? createdAt,
  }) {
    return ConnectionRequest(
      id: id ?? this.id,
      requesterId: requesterId ?? this.requesterId,
      requesterName: requesterName ?? this.requesterName,
      requesterAvatar: requesterAvatar ?? this.requesterAvatar,
      requesterTitle: requesterTitle ?? this.requesterTitle,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() => 'ConnectionRequest(id: $id, from: $requesterName)';
}

// Extension pour les statuts de connexion
extension ConnectionStatusExtension on String? {
  bool get isAccepted => this == 'accepted';
  bool get isPending => this == 'pending';
  bool get isRejected => this == 'rejected';
  
  String get statusLabel {
    switch (this) {
      case 'accepted':
        return 'Connecté';
      case 'pending':
        return 'En attente';
      case 'rejected':
        return 'Refusé';
      default:
        return 'Inconnu';
    }
  }
  
  Color get statusColor {
    switch (this) {
      case 'accepted':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
