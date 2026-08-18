/// Représente un membre d'un groupe.
class GroupMember {
  final String userId;
  final String displayName;
  final String? avatarUrl;
  final String role; // 'admin', 'moderator', 'member'
  final bool isOnline;
  final DateTime joinedAt;

  const GroupMember({
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    this.role = 'member',
    this.isOnline = false,
    required this.joinedAt,
  });

  factory GroupMember.fromJson(Map<String, dynamic> json) {
    return GroupMember(
      userId: json['user_id'] ?? '',
      displayName: json['display_name'] ?? 'Utilisateur',
      avatarUrl: json['avatar_url'],
      role: json['role'] ?? 'member',
      isOnline: json['is_online'] ?? false,
      joinedAt: json['joined_at'] != null
          ? DateTime.parse(json['joined_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'display_name': displayName,
    'avatar_url': avatarUrl,
    'role': role,
    'is_online': isOnline,
    'joined_at': joinedAt.toIso8601String(),
  };

  bool get isAdmin => role == 'admin';
  bool get isModerator => role == 'moderator';
  bool get isMember => role == 'member';

  /// Couleur de badge selon le rôle (chartre THIX).
  String get roleBadgeColor {
    switch (role) {
      case 'admin':
        return '#E3B23C'; // or
      case 'moderator':
        return '#2D6CDF'; // bleu
      default:
        return '#6B7690'; // gris
    }
  }
}

/// Informations complètes d'un groupe de discussion.
class GroupInfo {
  final String groupId;
  final String name;
  final String? avatarUrl;
  final String? description;
  final List<GroupMember> members;
  final List<String> adminIds; // Liste des userId admins (pour accès rapide)
  final bool isPublic;
  final String? inviteCode;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const GroupInfo({
    required this.groupId,
    required this.name,
    this.avatarUrl,
    this.description,
    required this.members,
    required this.adminIds,
    this.isPublic = false,
    this.inviteCode,
    required this.createdAt,
    this.updatedAt,
  });

  factory GroupInfo.fromJson(Map<String, dynamic> json) {
    final membersList = (json['members'] as List?)
        ?.map((e) => GroupMember.fromJson(e))
        .toList() ?? [];

    return GroupInfo(
      groupId: json['group_id'] ?? '',
      name: json['name'] ?? '',
      avatarUrl: json['avatar_url'],
      description: json['description'],
      members: membersList,
      adminIds: (json['admin_ids'] as List?)?.map((e) => e.toString()).toList() ?? [],
      isPublic: json['is_public'] ?? false,
      inviteCode: json['invite_code'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'group_id': groupId,
    'name': name,
    'avatar_url': avatarUrl,
    'description': description,
    'members': members.map((m) => m.toJson()).toList(),
    'admin_ids': adminIds,
    'is_public': isPublic,
    'invite_code': inviteCode,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
  };

  // ============================================================
  // ✅ COPYWITH AJOUTÉ
  // ============================================================

  /// Crée une copie de ce [GroupInfo] avec les champs modifiés.
  GroupInfo copyWith({
    String? groupId,
    String? name,
    String? avatarUrl,
    String? description,
    List<GroupMember>? members,
    List<String>? adminIds,
    bool? isPublic,
    String? inviteCode,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return GroupInfo(
      groupId: groupId ?? this.groupId,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      description: description ?? this.description,
      members: members ?? this.members,
      adminIds: adminIds ?? this.adminIds,
      isPublic: isPublic ?? this.isPublic,
      inviteCode: inviteCode ?? this.inviteCode,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // ============================================================
  // GETTERS
  // ============================================================

  /// Nombre total de membres.
  int get memberCount => members.length;

  /// Nombre de membres en ligne.
  int get onlineCount => members.where((m) => m.isOnline).length;

  /// Récupère un membre par son userId.
  GroupMember? getMember(String userId) {
    try {
      return members.firstWhere((m) => m.userId == userId);
    } catch (_) {
      return null;
    }
  }

  /// Vérifie si un utilisateur est admin.
  bool isAdmin(String userId) => adminIds.contains(userId);

  /// Vérifie si un utilisateur est modérateur (ou admin).
  bool isModeratorOrAdmin(String userId) {
    final member = getMember(userId);
    return member != null && (member.isAdmin || member.isModerator);
  }
}
