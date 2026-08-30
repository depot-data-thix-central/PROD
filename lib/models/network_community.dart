// lib/models/network_community.dart
import 'package:flutter/material.dart';

class NetworkCommunity {
  final String id;
  final String name;
  final String? description;
  final String? logoUrl;          //  : URL du logo
  final String? bannerUrl;
  final String privacy;           //  'public', 'private', 'connections'
  final String? domain;           // : Correction de l'erreur de compilation
  final int membersCount;
  final int postsCount;
  final String? createdBy;
  final String? creatorName;
  final DateTime createdAt;
  final bool isMember;

  NetworkCommunity({
    required this.id,
    required this.name,
    this.description,
    this.logoUrl,
    this.bannerUrl,
    this.privacy = 'public',      //  Valeur par défaut
    this.domain,                  // AJOUT
    required this.membersCount,
    required this.postsCount,
    this.createdBy,
    this.creatorName,
    required this.createdAt,
    this.isMember = false,
  });

  // Constructeur vide pour les tests
  NetworkCommunity.empty()
      : id = '',
        name = '',
        description = null,
        logoUrl = null,
        bannerUrl = null,
        privacy = 'public',
        domain = null,            //  AJOUT
        membersCount = 0,
        postsCount = 0,
        createdBy = null,
        creatorName = null,
        createdAt = DateTime.now(),
        isMember = false;

  // Getters utilitaires
  bool get isValid => name.isNotEmpty && membersCount >= 0;
  bool get hasLogo => logoUrl != null && logoUrl!.isNotEmpty;
  bool get hasBanner => bannerUrl != null && bannerUrl!.isNotEmpty;
  bool get hasDescription => description != null && description!.isNotEmpty;
  bool get isAdmin => createdBy != null;
  
  String get formattedMemberCount {
    if (membersCount >= 1000000) {
      return '${(membersCount / 1000000).toStringAsFixed(1)}M';
    } else if (membersCount >= 1000) {
      return '${(membersCount / 1000).toStringAsFixed(1)}k';
    }
    return membersCount.toString();
  }
  
  String get formattedPostCount {
    if (postsCount >= 1000000) {
      return '${(postsCount / 1000000).toStringAsFixed(1)}M';
    } else if (postsCount >= 1000) {
      return '${(postsCount / 1000).toStringAsFixed(1)}k';
    }
    return postsCount.toString();
  }
  
  String get initials => name.isNotEmpty ? name[0].toUpperCase() : '?';
  
  String get logoOrDefault => hasLogo ? logoUrl! : '';
  String get bannerOrDefault => hasBanner ? bannerUrl! : '';

  factory NetworkCommunity.fromJson(Map<String, dynamic> json) {
    final creator = json['creator'] as Map<String, dynamic>?;
    
    return NetworkCommunity(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      logoUrl: json['logo_url']?.toString() ?? json['logoUrl']?.toString(),
      bannerUrl: json['banner_url']?.toString() ?? json['bannerUrl']?.toString(),
      privacy: json['privacy']?.toString() ?? 'public',
      domain: json['domain']?.toString(), 
      membersCount: (json['members_count'] as int?) ?? 0,
      postsCount: (json['posts_count'] as int?) ?? 0,
      createdBy: json['created_by']?.toString(),
      creatorName: creator?['display_name']?.toString(),
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String) 
          : DateTime.now(),
      isMember: (json['is_member'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'logo_url': logoUrl,
    'banner_url': bannerUrl,
    'privacy': privacy,
    'domain': domain,                     
    'members_count': membersCount,
    'posts_count': postsCount,
    'created_by': createdBy,
    'created_at': createdAt.toIso8601String(),
  };

  NetworkCommunity copyWith({
    String? id,
    String? name,
    String? description,
    String? logoUrl,
    String? bannerUrl,
    String? privacy,
    String? domain,                       
    int? membersCount,
    int? postsCount,
    String? createdBy,
    String? creatorName,
    DateTime? createdAt,
    bool? isMember,
  }) {
    return NetworkCommunity(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      logoUrl: logoUrl ?? this.logoUrl,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      privacy: privacy ?? this.privacy,
      domain: domain ?? this.domain,      
      membersCount: membersCount ?? this.membersCount,
      postsCount: postsCount ?? this.postsCount,
      createdBy: createdBy ?? this.createdBy,
      creatorName: creatorName ?? this.creatorName,
      createdAt: createdAt ?? this.createdAt,
      isMember: isMember ?? this.isMember,
    );
  }

  @override
  String toString() => 'NetworkCommunity(id: $id, name: $name, members: $membersCount)';
}

// Extension pour les rôles (inchangée)
extension CommunityRoleExtension on String? {
  bool get isAdmin => this == 'admin';
  bool get isModerator => this == 'moderator' || isAdmin;
  bool get isMember => this == 'member' || isModerator;
  
  String get roleLabel {
    switch (this) {
      case 'admin':
        return 'Administrateur';
      case 'moderator':
        return 'Modérateur';
      default:
        return 'Membre';
    }
  }
  
  Color get roleColor {
    switch (this) {
      case 'admin':
        return Colors.amber;
      case 'moderator':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}

class CommunityMember {
  final String id;
  final String userId;
  final String userName;
  final String? userAvatar;
  final String userTitle;
  final String? role;
  final DateTime joinedAt;

  CommunityMember({
    required this.id,
    required this.userId,
    required this.userName,
    this.userAvatar,
    required this.userTitle,
    this.role,
    required this.joinedAt,
  });

  // Constructeur vide
  CommunityMember.empty()
      : id = '',
        userId = '',
        userName = '',
        userAvatar = null,
        userTitle = '',
        role = null,
        joinedAt = DateTime.now();

  // Getters
  bool get hasAvatar => userAvatar != null && userAvatar!.isNotEmpty;
  String get avatarUrl => hasAvatar ? userAvatar! : '';
  String get initials => userName.isNotEmpty ? userName[0].toUpperCase() : '?';
  bool get isAdminRole => role.isAdmin;
  bool get isModeratorRole => role.isModerator;
  
  String get joinedAtFormatted {
    final now = DateTime.now();
    final diff = now.difference(joinedAt);
    
    if (diff.inDays > 30) {
      return 'Membre depuis ${joinedAt.day}/${joinedAt.month}/${joinedAt.year}';
    } else if (diff.inDays > 0) {
      return 'Membre depuis ${diff.inDays} jours';
    } else {
      return 'Nouveau membre';
    }
  }

  factory CommunityMember.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;
    
    return CommunityMember(
      id: json['id']?.toString() ?? '',
      userId: user?['id']?.toString() ?? json['user_id']?.toString() ?? '',
      userName: user?['display_name']?.toString() ?? 'Utilisateur',
      userAvatar: user?['avatar_url']?.toString(),
      userTitle: user?['title']?.toString() ?? 'Membre',
      role: json['role']?.toString() ?? 'member',
      joinedAt: json['joined_at'] != null 
          ? DateTime.parse(json['joined_at'] as String) 
          : DateTime.now(),
    );
  }
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'user_name': userName,
    'user_avatar': userAvatar,
    'user_title': userTitle,
    'role': role,
    'joined_at': joinedAt.toIso8601String(),
  };

  CommunityMember copyWith({
    String? id,
    String? userId,
    String? userName,
    String? userAvatar,
    String? userTitle,
    String? role,
    DateTime? joinedAt,
  }) {
    return CommunityMember(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userAvatar: userAvatar ?? this.userAvatar,
      userTitle: userTitle ?? this.userTitle,
      role: role ?? this.role,
      joinedAt: joinedAt ?? this.joinedAt,
    );
  }

  @override
  String toString() => 'CommunityMember(id: $id, name: $userName, role: $role)';
}
