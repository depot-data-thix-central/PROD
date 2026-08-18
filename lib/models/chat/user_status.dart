import 'package:flutter/material.dart';

class UserStatus {
  // Constantes de statut
  static const String online = 'online';
  static const String busy = 'busy';
  static const String away = 'away';
  static const String doNotDisturb = 'do_not_disturb';
  static const String offline = 'offline';

  // Liste de tous les statuts
  static const List<String> all = [
    online,
    busy,
    away,
    doNotDisturb,
    offline,
  ];

  // ---- CHAMPS DE DONNÉES ----
  final String userId;
  final String status;
  final String? customStatus;
  final DateTime lastSeenAt;
  final DateTime updatedAt;
  final String? username;
  final String? fullName;
  final String? avatarUrl;

  UserStatus({
    required this.userId,
    required this.status,
    this.customStatus,
    required this.lastSeenAt,
    required this.updatedAt,
    this.username,
    this.fullName,
    this.avatarUrl,
  });

  // ---- FACTORY FROM JSON ----
  factory UserStatus.fromJson(Map<String, dynamic> json) {
    final profile = json['profiles'] as Map<String, dynamic>?;
    
    return UserStatus(
      userId: json['user_id'] ?? '',
      status: json['status'] ?? 'offline',
      customStatus: json['custom_status'],
      lastSeenAt: json['last_seen_at'] != null
          ? DateTime.parse(json['last_seen_at'])
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : DateTime.now(),
      username: profile?['username'],
      fullName: profile?['full_name'],
      avatarUrl: profile?['avatar_url'],
    );
  }

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'status': status,
    'custom_status': customStatus,
    'last_seen_at': lastSeenAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  // ---- GETTERS ----
  String get displayName => fullName ?? username ?? 'Utilisateur inconnu';
  bool get isOnline => status == online;
  bool get isOffline => status == offline;
  bool get isBusy => status == busy;
  bool get isAway => status == away;
  bool get isDoNotDisturb => status == doNotDisturb;

  Color get color => getColor(status);
  IconData get icon => getIcon(status);
  String get label => getLabel(status);

  // ---- MÉTHODES STATIQUES EXISTANTES ----
  static String getLabel(String status) {
    switch (status) {
      case online:
        return 'En ligne';
      case busy:
        return 'Occupé';
      case away:
        return 'Absent';
      case doNotDisturb:
        return 'Ne pas déranger';
      case offline:
        return 'Hors ligne';
      default:
        return 'Inconnu';
    }
  }

  static IconData getIcon(String status) {
    switch (status) {
      case online:
        return Icons.circle;
      case busy:
        return Icons.do_not_disturb;
      case away:
        return Icons.timer;
      case doNotDisturb:
        return Icons.phone_android;
      case offline:
        return Icons.circle_outlined;
      default:
        return Icons.help_outline;
    }
  }

  static Color getColor(String status) {
    switch (status) {
      case online:
        return Colors.green;
      case busy:
        return Colors.orange;
      case away:
        return Colors.amber;
      case doNotDisturb:
        return Colors.red;
      case offline:
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  static Widget presenceIndicator(String status, {double size = 12}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: getColor(status),
        border: Border.all(color: Colors.white, width: 2),
      ),
    );
  }
}
