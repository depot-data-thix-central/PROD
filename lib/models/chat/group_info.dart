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
}

/// Paramètres globaux du groupe
class GroupSettings {
  final bool onlyAdminsCanSendMessages;
  final bool onlyAdminsCanEditGroupInfo;
  final bool requireAdminApprovalForNewMembers;
  final bool disappearingMessagesEnabled;
  final int? disappearingMessagesDuration; // en secondes
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
  owner,      // Propriétaire du groupe (permissions maximales)
  admin,      // Administrateur
  moderator,  // Modérateur (peut supprimer messages, muter)
  editor,     // Éditeur (peut modifier description/avatar)
  member,     // Membre standard
  muted,      // Membre muté (lecture seule)
  observer,   // Observateur (lecture seule, pas de statut en ligne)
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
    }
  }

  String get badgeColor {
    switch (this) {
      case GroupRole.owner:
        return '#E3B23C'; // or
      case GroupRole.admin:
        return '#E3B23C'; // or
      case GroupRole.moderator:
        return '#2D6CDF'; // bleu
      case GroupRole.editor:
        return '#10B981'; // vert
      case GroupRole.member:
        return '#6B7690'; // gris
      case GroupRole.muted:
        return '#EF4444'; // rouge
      case GroupRole.observer:
        return '#8B5CF6'; // violet
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
  
  // ✅ NOUVEAUX CHAMPS (P0-P2)
  final DateTime? lastSeenAt;           // P0 : Indicateur "Dernier vu"
  final String? phoneNumber;            // P1 : Numéro masqué
  final DateTime? mutedUntil;           // P1 : Membre muté jusqu'à
  final String? addedBy;                // P1 : Qui a ajouté ce membre
  final String? internalNote;           // P2 : Note interne (agents/support)
  final GroupPermissions? permissions;  // P2 : Permissions personnalisées

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

  /// Crée une copie avec les champs modifiés
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

  /// Vérifie si le membre a un rôle avec privilèges (admin, modérateur, éditeur)
  bool get hasPrivileges => isAdmin || isModerator || isEditor;

  // ============================================================
  // ✅ NOUVEAUX GETTERS (P0-P2)
  // ============================================================

  /// P1 : Badge "Nouveau membre" si rejoint il y a moins de 7 jours
  bool get isNewMember {
    final diff = DateTime.now().difference(joinedAt);
    return diff.inDays < 7;
  }

  /// P1 : Texte formaté pour "Dernier vu"
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

  /// P1 : Numéro de téléphone masqué (ex: +33 *** *** 78 90)
  String? get maskedPhoneNumber {
    if (phoneNumber == null || phoneNumber!.isEmpty) return null;
    
    final clean = phoneNumber!.replaceAll(RegExp(r'[^\d+]'), '');
    if (clean.length <= 6) return phoneNumber;
    
    // Masquer le milieu : garder les 3 premiers et 4 derniers caractères
    final prefix = clean.substring(0, 3);
    final suffix = clean.substring(clean.length - 4);
    return '$prefix *** *** $suffix';
  }

  /// P2 : Permissions effectives (custom ou par défaut selon le rôle)
  GroupPermissions get effectivePermissions {
    return permissions ?? role.defaultPermissions;
  }

  /// P2 : Vérifie si le membre peut effectuer une action
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

  /// Couleur de badge selon le rôle (chartre THIX)
  String get roleBadgeColor => role.badgeColor;

  /// Initiale pour l'avatar fallback
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
  
  // ✅ NOUVEAUX CHAMPS (P0-P2)
  final GroupSettings settings;         // P2 : Paramètres globaux
  final String? createdBy;              // P1 : Créateur du groupe
  final List<String> commonGroupIds;    // P2 : Groupes en commun avec l'utilisateur courant

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

  /// Crée une copie avec les champs modifiés
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

  /// Nombre total de membres
  int get memberCount => members.length;

  /// Nombre de membres en ligne
  int get onlineCount => members.where((m) => m.isOnline).length;

  /// Nombre d'admins
  int get adminCount => members.where((m) => m.isAdmin).length;

  /// Nombre de nouveaux membres (< 7 jours)
  int get newMemberCount => members.where((m) => m.isNewMember).length;

  /// Récupère un membre par son userId
  GroupMember? getMember(String userId) {
    try {
      return members.firstWhere((m) => m.userId == userId);
    } catch (_) {
      return null;
    }
  }

  /// Vérifie si un utilisateur est admin
  bool isAdmin(String userId) => adminIds.contains(userId);

  /// Vérifie si un utilisateur est modérateur (ou admin)
  bool isModeratorOrAdmin(String userId) {
    final member = getMember(userId);
    return member != null && (member.isAdmin || member.isModerator);
  }

  // ============================================================
  // ✅ NOUVEAUX GETTERS (P0-P2)
  // ============================================================

  /// P0 : Membres triés (admins d'abord, puis en ligne, puis alphabétique)
  List<GroupMember> get sortedMembers {
    final admins = members.where((m) => m.isAdmin).toList();
    final online = members.where((m) => !m.isAdmin && m.isOnline).toList();
    final offline = members.where((m) => !m.isAdmin && !m.isOnline).toList();

    admins.sort((a, b) => a.displayName.compareTo(b.displayName));
    online.sort((a, b) => a.displayName.compareTo(b.displayName));
    offline.sort((a, b) => a.displayName.compareTo(b.displayName));

    return [...admins, ...online, ...offline];
  }

  /// P0 : Recherche dans la liste des membres
  List<GroupMember> searchMembers(String query) {
    if (query.isEmpty) return members;
    
    final lowerQuery = query.toLowerCase();
    return members.where((m) {
      return m.displayName.toLowerCase().contains(lowerQuery) ||
             (m.phoneNumber?.contains(query) ?? false);
    }).toList();
  }

  /// P0 : Sections séparées (Admins / Membres)
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

  /// P2 : Vérifie si l'utilisateur courant peut effectuer une action
  bool canUserPerform(String userId, GroupPermissionAction action) {
    final member = getMember(userId);
    if (member == null) return false;
    
    // Les admins peuvent tout faire
    if (member.isAdmin) return true;
    
    // Vérifier les paramètres globaux du groupe
    if (action == GroupPermissionAction.sendMessage && settings.onlyAdminsCanSendMessages) {
      return false;
    }
    if (action == GroupPermissionAction.editGroupInfo && settings.onlyAdminsCanEditGroupInfo) {
      return false;
    }
    
    // Vérifier les permissions du membre
    return member.canPerform(action);
  }

  /// P2 : Lien d'invitation complet
  String? get inviteLink {
    if (inviteCode == null) return null;
    return 'https://thix.chat/join/$inviteCode';
  }

  /// P2 : Âge du groupe en jours
  int get ageInDays => DateTime.now().difference(createdAt).inDays;

  /// P2 : Texte formaté pour la date de création
  String get formattedCreatedAt {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inDays < 1) return 'Créé aujourd\'hui';
    if (diff.inDays < 7) return 'Créé il y a ${diff.inDays} jours';
    if (diff.inDays < 30) return 'Créé il y a ${(diff.inDays / 7).floor()} semaines';
    if (diff.inDays < 365) return 'Créé il y a ${(diff.inDays / 30).floor()} mois';
    return 'Créé il y a ${(diff.inDays / 365).floor()} ans';
  }
}
