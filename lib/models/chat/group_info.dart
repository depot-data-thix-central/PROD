// lib/models/chat/group_info.dart
//
// ============================================================================
// GROUP INFO MODEL — Production Enterprise++ (Dépasse WhatsApp)
// ============================================================================
// ✅ 8 rôles : owner, admin, moderator, editor, member, muted, observer, bot
// ✅ Permissions granulaires
// ✅ Settings globaux
// ✅ Zéro syntaxe Dart 3 (compatible analyzer 3.4.0)
// ============================================================================

/// Permissions granulaires d'un membre ou du groupe
class GroupPermissions {
  final bool canSendMessages;
  final bool canSendMedia;
  final bool canSendStickers;
  final bool canEditGroupInfo;
  final bool canAddMembers;
  final bool canRemoveMembers;
  final bool canPinMessages;
  final bool canDeleteMessages;
  final bool canMuteMembers;
  final bool canInviteViaLink;

  const GroupPermissions({
    this.canSendMessages = true,
    this.canSendMedia = true,
    this.canSendStickers = true,
    this.canEditGroupInfo = false,
    this.canAddMembers = false,
    this.canRemoveMembers = false,
    this.canPinMessages = false,
    this.canDeleteMessages = false,
    this.canMuteMembers = false,
    this.canInviteViaLink = false,
  });

  factory GroupPermissions.fromJson(Map<String, dynamic> json) {
    return GroupPermissions(
      canSendMessages: json['can_send_messages'] ?? true,
      canSendMedia: json['can_send_media'] ?? true,
      canSendStickers: json['can_send_stickers'] ?? true,
      canEditGroupInfo: json['can_edit_group_info'] ?? false,
      canAddMembers: json['can_add_members'] ?? false,
      canRemoveMembers: json['can_remove_members'] ?? false,
      canPinMessages: json['can_pin_messages'] ?? false,
      canDeleteMessages: json['can_delete_messages'] ?? false,
      canMuteMembers: json['can_mute_members'] ?? false,
      canInviteViaLink: json['can_invite_via_link'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'can_send_messages': canSendMessages,
    'can_send_media': canSendMedia,
    'can_send_stickers': canSendStickers,
    'can_edit_group_info': canEditGroupInfo,
    'can_add_members': canAddMembers,
    'can_remove_members': canRemoveMembers,
    'can_pin_messages': canPinMessages,
    'can_delete_messages': canDeleteMessages,
    'can_mute_members': canMuteMembers,
    'can_invite_via_link': canInviteViaLink,
  };

  GroupPermissions copyWith({
    bool? canSendMessages,
    bool? canSendMedia,
    bool? canSendStickers,
    bool? canEditGroupInfo,
    bool? canAddMembers,
    bool? canRemoveMembers,
    bool? canPinMessages,
    bool? canDeleteMessages,
    bool? canMuteMembers,
    bool? canInviteViaLink,
  }) {
    return GroupPermissions(
      canSendMessages: canSendMessages ?? this.canSendMessages,
      canSendMedia: canSendMedia ?? this.canSendMedia,
      canSendStickers: canSendStickers ?? this.canSendStickers,
      canEditGroupInfo: canEditGroupInfo ?? this.canEditGroupInfo,
      canAddMembers: canAddMembers ?? this.canAddMembers,
      canRemoveMembers: canRemoveMembers ?? this.canRemoveMembers,
      canPinMessages: canPinMessages ?? this.canPinMessages,
      canDeleteMessages: canDeleteMessages ?? this.canDeleteMessages,
      canMuteMembers: canMuteMembers ?? this.canMuteMembers,
      canInviteViaLink: canInviteViaLink ?? this.canInviteViaLink,
    );
  }

  /// Permissions par défaut pour un membre standard
  static const GroupPermissions defaultMember = GroupPermissions();

  /// Permissions pour un modérateur
  static const GroupPermissions moderator = GroupPermissions(
    canPinMessages: true,
    canDeleteMessages: true,
    canMuteMembers: true,
  );

  /// Permissions pour un admin (toutes les permissions)
  static const GroupPermissions admin = GroupPermissions(
    canSendMessages: true,
    canSendMedia: true,
    canSendStickers: true,
    canEditGroupInfo: true,
    canAddMembers: true,
    canRemoveMembers: true,
    canPinMessages: true,
    canDeleteMessages: true,
    canMuteMembers: true,
    canInviteViaLink: true,
  );

  /// Permissions pour un bot (lecture + envoi de messages)
  static const GroupPermissions bot = GroupPermissions(
    canSendMessages: true,
    canSendMedia: false,
    canSendStickers: false,
    canEditGroupInfo: false,
    canAddMembers: false,
    canRemoveMembers: false,
    canPinMessages: false,
    canDeleteMessages: false,
    canMuteMembers: false,
    canInviteViaLink: false,
  );
}

/// Paramètres globaux du groupe
class GroupSettings {
  final bool onlyAdminsCanSendMessages;
  final bool onlyAdminsCanEditGroupInfo;
  final bool requireAdminApprovalForNewMembers;
  final bool disappearingMessagesEnabled;
  final int? disappearingMessagesDuration;
  final bool allowReactions;
  final bool allowForwarding;

  const GroupSettings({
    this.onlyAdminsCanSendMessages = false,
    this.onlyAdminsCanEditGroupInfo = false,
    this.requireAdminApprovalForNewMembers = false,
    this.disappearingMessagesEnabled = false,
    this.disappearingMessagesDuration,
    this.allowReactions = true,
    this.allowForwarding = true,
  });

  factory GroupSettings.fromJson(Map<String, dynamic> json) {
    return GroupSettings(
      onlyAdminsCanSendMessages: json['only_admins_can_send_messages'] ?? false,
      onlyAdminsCanEditGroupInfo: json['only_admins_can_edit_group_info'] ?? false,
      requireAdminApprovalForNewMembers: json['require_admin_approval_for_new_members'] ?? false,
      disappearingMessagesEnabled: json['disappearing_messages_enabled'] ?? false,
      disappearingMessagesDuration: json['disappearing_messages_duration'],
      allowReactions: json['allow_reactions'] ?? true,
      allowForwarding: json['allow_forwarding'] ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'only_admins_can_send_messages': onlyAdminsCanSendMessages,
    'only_admins_can_edit_group_info': onlyAdminsCanEditGroupInfo,
    'require_admin_approval_for_new_members': requireAdminApprovalForNewMembers,
    'disappearing_messages_enabled': disappearingMessagesEnabled,
    'disappearing_messages_duration': disappearingMessagesDuration,
    'allow_reactions': allowReactions,
    'allow_forwarding': allowForwarding,
  };

  GroupSettings copyWith({
    bool? onlyAdminsCanSendMessages,
    bool? onlyAdminsCanEditGroupInfo,
    bool? requireAdminApprovalForNewMembers,
    bool? disappearingMessagesEnabled,
    int? disappearingMessagesDuration,
    bool? allowReactions,
    bool? allowForwarding,
  }) {
    return GroupSettings(
      onlyAdminsCanSendMessages: onlyAdminsCanSendMessages ?? this.onlyAdminsCanSendMessages,
      onlyAdminsCanEditGroupInfo: onlyAdminsCanEditGroupInfo ?? this.onlyAdminsCanEditGroupInfo,
      requireAdminApprovalForNewMembers: requireAdminApprovalForNewMembers ?? this.requireAdminApprovalForNewMembers,
      disappearingMessagesEnabled: disappearingMessagesEnabled ?? this.disappearingMessagesEnabled,
      disappearingMessagesDuration: disappearingMessagesDuration ?? this.disappearingMessagesDuration,
      allowReactions: allowReactions ?? this.allowReactions,
      allowForwarding: allowForwarding ?? this.allowForwarding,
    );
  }
}

/// Rôles possibles dans un groupe
enum GroupRole {
  owner,
  admin,
  moderator,
  editor,
  member,
  muted,
  observer,
  bot, // ✅ AJOUTÉ
}

extension GroupRoleX on GroupRole {
  String get name {
    switch (this) {
      case GroupRole.owner:
        return 'owner';
      case GroupRole.admin:
        return 'admin';
      case GroupRole.moderator:
        return 'moderator';
      case GroupRole.editor:
        return 'editor';
      case GroupRole.member:
        return 'member';
      case GroupRole.muted:
        return 'muted';
      case GroupRole.observer:
        return 'observer';
      case GroupRole.bot: // ✅ AJOUTÉ
        return 'bot';
    }
  }

  String get displayName {
    switch (this) {
      case GroupRole.owner:
        return 'Propriétaire';
      case GroupRole.admin:
        return 'Admin';
      case GroupRole.moderator:
        return 'Modérateur';
      case GroupRole.editor:
        return 'Éditeur';
      case GroupRole.member:
        return 'Membre';
      case GroupRole.muted:
        return 'Muté';
      case GroupRole.observer:
        return 'Observateur';
      case GroupRole.bot: // ✅ AJOUTÉ
        return 'Bot';
    }
  }

  String get badgeColor {
    switch (this) {
      case GroupRole.owner:
        return '#E3B23C';
      case GroupRole.admin:
        return '#E3B23C';
      case GroupRole.moderator:
        return '#2D6CDF';
      case GroupRole.editor:
        return '#10B981';
      case GroupRole.member:
        return '#6B7690';
      case GroupRole.muted:
        return '#EF4444';
      case GroupRole.observer:
        return '#8B5CF6';
      case GroupRole.bot: // ✅ AJOUTÉ
        return '#6B7690';
    }
  }

  GroupPermissions get defaultPermissions {
    switch (this) {
      case GroupRole.owner:
      case GroupRole.admin:
        return GroupPermissions.admin;
      case GroupRole.moderator:
        return GroupPermissions.moderator;
      case GroupRole.editor:
        return const GroupPermissions(canEditGroupInfo: true);
      case GroupRole.muted:
      case GroupRole.observer:
        return const GroupPermissions(
          canSendMessages: false,
          canSendMedia: false,
          canSendStickers: false,
        );
      case GroupRole.member:
        return GroupPermissions.defaultMember;
      case GroupRole.bot: // ✅ AJOUTÉ
        return GroupPermissions.bot;
    }
  }

  static GroupRole fromString(String? role) {
    switch (role?.toLowerCase()) {
      case 'owner':
        return GroupRole.owner;
      case 'admin':
        return GroupRole.admin;
      case 'moderator':
        return GroupRole.moderator;
      case 'editor':
        return GroupRole.editor;
      case 'muted':
        return GroupRole.muted;
      case 'observer':
        return GroupRole.observer;
      case 'bot': // ✅ AJOUTÉ
        return GroupRole.bot;
      case 'member':
      default:
        return GroupRole.member;
    }
  }
}

/// Représente un membre d'un groupe avec toutes les fonctionnalités WhatsApp
class GroupMember {
  final String userId;
  final String displayName;
  final String? avatarUrl;
  final GroupRole role;
  final bool isOnline;
  final DateTime joinedAt;

  final DateTime? lastSeenAt;
  final String? phoneNumber;
  final DateTime? mutedUntil;
  final String? addedBy;
  final String? internalNote;
  final GroupPermissions? permissions;

  const GroupMember({
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    this.role = GroupRole.member,
    this.isOnline = false,
    required this.joinedAt,
    this.lastSeenAt,
    this.phoneNumber,
    this.mutedUntil,
    this.addedBy,
    this.internalNote,
    this.permissions,
  });

  factory GroupMember.fromJson(Map<String, dynamic> json) {
    return GroupMember(
      userId: json['user_id'] ?? '',
      displayName: json['display_name'] ?? 'Utilisateur',
      avatarUrl: json['avatar_url'],
      role: GroupRoleX.fromString(json['role']),
      isOnline: json['is_online'] ?? false,
      joinedAt: json['joined_at'] != null
          ? DateTime.parse(json['joined_at'])
          : DateTime.now(),
      lastSeenAt: json['last_seen_at'] != null
          ? DateTime.parse(json['last_seen_at'])
          : null,
      phoneNumber: json['phone_number'],
      mutedUntil: json['muted_until'] != null
          ? DateTime.parse(json['muted_until'])
          : null,
      addedBy: json['added_by'],
      internalNote: json['internal_note'],
      permissions: json['permissions'] != null
          ? GroupPermissions.fromJson(json['permissions'])
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'display_name': displayName,
    'avatar_url': avatarUrl,
    'role': role.name,
    'is_online': isOnline,
    'joined_at': joinedAt.toIso8601String(),
    'last_seen_at': lastSeenAt?.toIso8601String(),
    'phone_number': phoneNumber,
    'muted_until': mutedUntil?.toIso8601String(),
    'added_by': addedBy,
    'internal_note': internalNote,
    'permissions': permissions?.toJson(),
  };

  GroupMember copyWith({
    String? userId,
    String? displayName,
    String? avatarUrl,
    GroupRole? role,
    bool? isOnline,
    DateTime? joinedAt,
    DateTime? lastSeenAt,
    String? phoneNumber,
    DateTime? mutedUntil,
    String? addedBy,
    String? internalNote,
    GroupPermissions? permissions,
  }) {
    return GroupMember(
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      role: role ?? this.role,
      isOnline: isOnline ?? this.isOnline,
      joinedAt: joinedAt ?? this.joinedAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      mutedUntil: mutedUntil ?? this.mutedUntil,
      addedBy: addedBy ?? this.addedBy,
      internalNote: internalNote ?? this.internalNote,
      permissions: permissions ?? this.permissions,
    );
  }

  // ============================================================
  // GETTERS DE RÔLE
  // ============================================================

  bool get isOwner => role == GroupRole.owner;
  bool get isAdmin => role == GroupRole.admin || role == GroupRole.owner;
  bool get isModerator => role == GroupRole.moderator;
  bool get isEditor => role == GroupRole.editor;
  bool get isMember => role == GroupRole.member;
  bool get isMuted => role == GroupRole.muted || (mutedUntil != null && mutedUntil!.isAfter(DateTime.now()));
  bool get isObserver => role == GroupRole.observer;
  bool get isBot => role == GroupRole.bot; // ✅ AJOUTÉ

  bool get hasPrivileges => isAdmin || isModerator || isEditor;

  // ============================================================
  // GETTERS (P0-P2)
  // ============================================================

  bool get isNewMember {
    final diff = DateTime.now().difference(joinedAt);
    return diff.inDays < 7;
  }

  String formatLastSeen() {
    if (isOnline) return 'En ligne';
    if (lastSeenAt == null) return 'Vu récemment';

    final diff = DateTime.now().difference(lastSeenAt!);

    if (diff.inMinutes < 1) return 'Vu à l\'instant';
    if (diff.inMinutes < 60) return 'Vu il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Vu il y a ${diff.inHours} h';
    if (diff.inDays < 7) return 'Vu il y a ${diff.inDays} j';

    return 'Vu le ${lastSeenAt!.day}/${lastSeenAt!.month}/${lastSeenAt!.year}';
  }

  String? get maskedPhoneNumber {
    if (phoneNumber == null || phoneNumber!.isEmpty) return null;

    final clean = phoneNumber!.replaceAll(RegExp(r'[^\d+]'), '');
    if (clean.length <= 6) return phoneNumber;

    final prefix = clean.substring(0, 3);
    final suffix = clean.substring(clean.length - 4);
    return '$prefix *** *** $suffix';
  }

  GroupPermissions get effectivePermissions {
    return permissions ?? role.defaultPermissions;
  }

  bool canPerform(GroupPermissionAction action) {
    final perms = effectivePermissions;
    switch (action) {
      case GroupPermissionAction.sendMessage:
        return perms.canSendMessages && !isMuted;
      case GroupPermissionAction.sendMedia:
        return perms.canSendMedia && !isMuted;
      case GroupPermissionAction.sendSticker:
        return perms.canSendStickers && !isMuted;
      case GroupPermissionAction.editGroupInfo:
        return perms.canEditGroupInfo;
      case GroupPermissionAction.addMember:
        return perms.canAddMembers;
      case GroupPermissionAction.removeMember:
        return perms.canRemoveMembers;
      case GroupPermissionAction.pinMessage:
        return perms.canPinMessages;
      case GroupPermissionAction.deleteMessage:
        return perms.canDeleteMessages;
      case GroupPermissionAction.muteMember:
        return perms.canMuteMembers;
      case GroupPermissionAction.inviteViaLink:
        return perms.canInviteViaLink;
    }
  }

  String get roleBadgeColor => role.badgeColor;

  String get initial {
    if (displayName.isEmpty) return '?';
    return displayName.trim()[0].toUpperCase();
  }
}

/// Actions possibles dans un groupe
enum GroupPermissionAction {
  sendMessage,
  sendMedia,
  sendSticker,
  editGroupInfo,
  addMember,
  removeMember,
  pinMessage,
  deleteMessage,
  muteMember,
  inviteViaLink,
}

/// Informations complètes d'un groupe de discussion
class GroupInfo {
  final String groupId;
  final String name;
  final String? avatarUrl;
  final String? description;
  final List<GroupMember> members;
  final List<String> adminIds;
  final bool isPublic;
  final String? inviteCode;
  final DateTime createdAt;
  final DateTime? updatedAt;

  final GroupSettings settings;
  final String? createdBy;
  final List<String> commonGroupIds;

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
    this.settings = const GroupSettings(),
    this.createdBy,
    this.commonGroupIds = const [],
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
      settings: json['settings'] != null
          ? GroupSettings.fromJson(json['settings'])
          : const GroupSettings(),
      createdBy: json['created_by'],
      commonGroupIds: (json['common_group_ids'] as List?)
          ?.map((e) => e.toString())
          .toList() ?? [],
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
    'settings': settings.toJson(),
    'created_by': createdBy,
    'common_group_ids': commonGroupIds,
  };

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
    GroupSettings? settings,
    String? createdBy,
    List<String>? commonGroupIds,
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
      settings: settings ?? this.settings,
      createdBy: createdBy ?? this.createdBy,
      commonGroupIds: commonGroupIds ?? this.commonGroupIds,
    );
  }

  // ============================================================
  // GETTERS DE BASE
  // ============================================================

  int get memberCount => members.length;
  int get onlineCount => members.where((m) => m.isOnline).length;
  int get adminCount => members.where((m) => m.isAdmin).length;
  int get newMemberCount => members.where((m) => m.isNewMember).length;
  int get botCount => members.where((m) => m.isBot).length; // ✅ AJOUTÉ

  GroupMember? getMember(String userId) {
    try {
      return members.firstWhere((m) => m.userId == userId);
    } catch (_) {
      return null;
    }
  }

  bool isAdmin(String userId) => adminIds.contains(userId);

  bool isModeratorOrAdmin(String userId) {
    final member = getMember(userId);
    return member != null && (member.isAdmin || member.isModerator);
  }

  // ============================================================
  // GETTERS (P0-P2)
  // ============================================================

  List<GroupMember> get sortedMembers {
    final admins = members.where((m) => m.isAdmin).toList();
    final online = members.where((m) => !m.isAdmin && m.isOnline).toList();
    final offline = members.where((m) => !m.isAdmin && !m.isOnline).toList();

    admins.sort((a, b) => a.displayName.compareTo(b.displayName));
    online.sort((a, b) => a.displayName.compareTo(b.displayName));
    offline.sort((a, b) => a.displayName.compareTo(b.displayName));

    return [...admins, ...online, ...offline];
  }

  List<GroupMember> searchMembers(String query) {
    if (query.isEmpty) return members;

    final lowerQuery = query.toLowerCase();
    return members.where((m) {
      return m.displayName.toLowerCase().contains(lowerQuery) ||
             (m.phoneNumber?.contains(query) ?? false);
    }).toList();
  }

  Map<String, List<GroupMember>> get membersBySection {
    final admins = members.where((m) => m.isAdmin).toList();
    final regularMembers = members.where((m) => !m.isAdmin).toList();

    admins.sort((a, b) => a.displayName.compareTo(b.displayName));
    regularMembers.sort((a, b) => a.displayName.compareTo(b.displayName));

    return {
      'admins': admins,
      'members': regularMembers,
    };
  }

  bool canUserPerform(String userId, GroupPermissionAction action) {
    final member = getMember(userId);
    if (member == null) return false;

    if (member.isAdmin) return true;

    if (action == GroupPermissionAction.sendMessage && settings.onlyAdminsCanSendMessages) {
      return false;
    }
    if (action == GroupPermissionAction.editGroupInfo && settings.onlyAdminsCanEditGroupInfo) {
      return false;
    }

    return member.canPerform(action);
  }

  String? get inviteLink {
    if (inviteCode == null) return null;
    return 'https://thix.chat/join/$inviteCode';
  }

  int get ageInDays => DateTime.now().difference(createdAt).inDays;

  String get formattedCreatedAt {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inDays < 1) return 'Créé aujourd\'hui';
    if (diff.inDays < 7) return 'Créé il y a ${diff.inDays} jours';
    if (diff.inDays < 30) return 'Créé il y a ${(diff.inDays / 7).floor()} semaines';
    if (diff.inDays < 365) return 'Créé il y a ${(diff.inDays / 30).floor()} mois';
    return 'Créé il y a ${(diff.inDays / 365).floor()} ans';
  }
}
