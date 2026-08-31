// lib/presentation/chat/group/group_info_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/presentation/chat/screens/group_settings_page.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/models/chat/chat_conversation.dart';
import 'package:thix_id/models/chat/group_info.dart';
import 'package:thix_id/presentation/chat/group/group_badge.dart';
import 'package:thix_id/presentation/chat/group/group_member_list.dart';
import 'package:thix_id/services/chat/chat_service.dart';
import 'package:thix_id/services/chat/group_service.dart';

// ============================================================================
// CONSTANTS
// ============================================================================
const double _kAvatarRadius = 50.0;
const double _kAvatarInitialFontSize = 36.0;
const double _kCodeFontSize = 14.0;
const int _kMaxDisplayNameLength = 100;

// ============================================================================
// VALIDATORS
// ============================================================================
class _GroupInfoValidators {
  _GroupInfoValidators._();

  /// Sanitize une entrée (XSS + caractères de contrôle)
  static String sanitize(String? input, {int maxLength = 500}) {
    if (input == null || input.trim().isEmpty) return '';
    final doc = html_parser.parse(input);
    var s = doc.body?.text ?? input;
    s = s
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'javascript:', caseSensitive: false), '')
        .replaceAll(RegExp(r'on\w+\s*=', caseSensitive: false), '')
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        .trim();
    return s.length > maxLength ? s.substring(0, maxLength) : s;
  }

  /// Retourne une initiale safe (pas de crash sur chaîne vide)
  static String safeInitial(String? name) {
    if (name == null || name.trim().isEmpty) return '?';
    return name.trim()[0].toUpperCase();
  }

  static String friendlyError(dynamic e, AppLocalizations l10n) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('not admin') || msg.contains('permission')) {
      return l10n.t('group_error_not_admin');
    }
    if (msg.contains('not found')) {
      return l10n.t('group_error_not_found');
    }
    if (msg.contains('network') || msg.contains('timeout')) {
      return l10n.t('group_error_network');
    }
    if (msg.contains('last admin')) {
      return l10n.t('group_error_last_admin');
    }
    return l10n.t('group_error_generic');
  }
}

// ============================================================================
// GROUP INFO PAGE
// ============================================================================

/// Écran affichant les informations détaillées d'un groupe.
///
/// Affiche :
/// - Avatar, nom, nombre de membres en ligne
/// - Description (si différente du nom)
/// - Code d'invitation (copiable)
/// - Liste des membres avec actions admin
/// - Actions : Gérer (admin) / Quitter (membre) / Supprimer (admin)
class GroupInfoPage extends StatefulWidget {
  final String groupId;

  const GroupInfoPage({super.key, required this.groupId});

  @override
  State<GroupInfoPage> createState() => _GroupInfoPageState();
}

class _GroupInfoPageState extends State<GroupInfoPage> {
  late GroupService _groupService;
  late ChatService _chatService;
  GroupInfo? _groupInfo;
  ChatConversation? _conversation;
  bool _isLoading = true;
  bool _isProcessing = false; // Protection double-tap
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _groupService = GroupService(Supabase.instance.client);
    _chatService = ChatService(Supabase.instance.client);
    _currentUserId = _chatService.currentUserId;
    debugPrint('[GroupInfo] 🚀 Page opened for group: ${widget.groupId}');
    _loadData();
  }

  // ── FEEDBACK HELPERS ──────────────────────────────────────────────────────

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ]),
        backgroundColor: ThixPolicy.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.error_outline_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ]),
        backgroundColor: ThixPolicy.danger,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showInfo(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.info_outline_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ]),
        backgroundColor: ThixPolicy.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ── LOAD DATA ─────────────────────────────────────────────────────────────

  Future<void> _loadData() async {
    final l10n = AppLocalizations.of(context);

    if (_currentUserId == null) {
      debugPrint('[GroupInfo] ❌ No current user ID');
      setState(() => _isLoading = false);
      _showError(l10n.t('group_error_no_user'));
      return;
    }

    setState(() => _isLoading = true);
    debugPrint('[GroupInfo] 🔄 Loading group data...');

    try {
      final conv = await _groupService.getGroupInfo(widget.groupId);
      final members = await _getMembers(widget.groupId);

      if (!mounted) return;

      setState(() {
        _conversation = conv;
        _groupInfo = GroupInfo(
          groupId: widget.groupId,
          name: _GroupInfoValidators.sanitize(conv.groupName, maxLength: _kMaxDisplayNameLength) ?? 'Groupe',
          avatarUrl: conv.groupAvatar,
          members: members,
          adminIds: members.where((m) => m.isAdmin).map((m) => m.userId).toList(),
          isPublic: false,
          createdAt: conv.updatedAt,
        );
        _isLoading = false;
      });

      debugPrint('[GroupInfo] ✓ Data loaded (${members.length} members)');
    } catch (e) {
      debugPrint('[GroupInfo] ❌ Load error: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError(_GroupInfoValidators.friendlyError(e, l10n));
    }
  }

  /// Récupère la liste des membres avec leur présence (en ligne).
  /// Optimisation : une seule requête pour la présence au lieu de N+1.
  Future<List<GroupMember>> _getMembers(String groupId) async {
    final supabase = Supabase.instance.client;

    // Récupère tous les participants avec profil en une seule requête
    final data = await supabase
        .from('conversation_participants')
        .select('''
          user_id,
          role,
          last_read_at,
          profiles!user_id (username, full_name, avatar_url)
        ''')
        .eq('conversation_id', groupId);

    // Récupère toutes les présences en une seule requête (optimisation N+1)
    final userIds = (data as List).map((p) => p['user_id'] as String).toList();
    final presences = userIds.isEmpty
        ? <Map<String, dynamic>>[]
        : await supabase
            .from('user_presence')
            .select('user_id, status')
            .inFilter('user_id', userIds);

    final presenceMap = <String, bool>{
      for (var p in presences) p['user_id'] as String: p['status'] == 'online',
    };

    final members = <GroupMember>[];
    for (var p in data) {
      final profile = p['profiles'] as Map<String, dynamic>?;
      final userId = p['user_id'] as String;
      final role = p['role'] as String? ?? 'member';
      final rawName = profile?['full_name'] ?? profile?['username'] ?? 'Utilisateur';

      members.add(GroupMember(
        userId: userId,
        displayName: _GroupInfoValidators.sanitize(rawName.toString(), maxLength: _kMaxDisplayNameLength),
        avatarUrl: profile?['avatar_url']?.toString(),
        role: role,
        isOnline: presenceMap[userId] ?? false,
        joinedAt: DateTime.tryParse(p['last_read_at']?.toString() ?? '') ?? DateTime.now(),
      ));
    }
    return members;
  }

  bool get _isAdmin => _currentUserId != null && _groupInfo?.isAdmin(_currentUserId!) == true;

  // ── NAVIGATION ────────────────────────────────────────────────────────────

  void _navigateToSettings() {
    HapticFeedback.selectionClick();
    debugPrint('[GroupInfo] ⚙️ Navigating to settings');
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => GroupSettingsPage(groupId: widget.groupId)),
    ).then((_) {
      if (mounted) _loadData();
    });
  }

  // ── COPY INVITE CODE ──────────────────────────────────────────────────────

  void _copyInviteCode() {
    final l10n = AppLocalizations.of(context);
    final code = _groupInfo?.inviteCode;

    if (code == null || code.isEmpty) {
      _showInfo(l10n.t('group_no_invite_code'));
      return;
    }

    HapticFeedback.selectionClick();
    Clipboard.setData(ClipboardData(text: code));
    _showSuccess(l10n.t('group_code_copied'));
    debugPrint('[GroupInfo] 📋 Invite code copied');
  }

  // ── LEAVE GROUP ───────────────────────────────────────────────────────────

  void _showLeaveGroupDialog() {
    final l10n = AppLocalizations.of(context);
    if (_isProcessing) return;

    HapticFeedback.mediumImpact();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThixPolicy.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(Icons.exit_to_app_rounded, color: ThixPolicy.danger, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l10n.t('group_leave_title'),
              style: ThixPolicy.titleStyle.copyWith(
                color: ThixPolicy.danger,
                fontWeight: ThixPolicy.bold,
              ),
            ),
          ),
        ]),
        content: Text(l10n.t('group_leave_message'), style: ThixPolicy.bodyStyle),
        actions: [
          TextButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.pop(ctx);
            },
            child: Text(l10n.t('cancel'), style: TextStyle(color: ThixPolicy.textMuted)),
          ),
          ElevatedButton(
            onPressed: () async {
              HapticFeedback.mediumImpact();
              Navigator.pop(ctx);
              await _leaveGroup();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: ThixPolicy.danger,
              foregroundColor: Colors.white,
            ),
            child: Text(l10n.t('group_leave_button')),
          ),
        ],
      ),
    );
  }

  Future<void> _leaveGroup() async {
    final l10n = AppLocalizations.of(context);
    if (_isProcessing) return;

    setState(() => _isProcessing = true);
    debugPrint('[GroupInfo] 🚪 Leaving group...');

    try {
      await _groupService.leaveGroup(widget.groupId);
      if (!mounted) return;
      Navigator.pop(context);
      _showSuccess(l10n.t('group_left_success'));
      debugPrint('[GroupInfo] ✓ Left group successfully');
    } catch (e) {
      debugPrint('[GroupInfo] ❌ Leave error: $e');
      if (!mounted) return;
      _showError(_GroupInfoValidators.friendlyError(e, l10n));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ── DELETE GROUP ──────────────────────────────────────────────────────────

  void _showDeleteGroupDialog() {
    final l10n = AppLocalizations.of(context);
    if (_isProcessing) return;

    HapticFeedback.mediumImpact();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThixPolicy.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(Icons.warning_rounded, color: ThixPolicy.danger, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l10n.t('group_delete_title'),
              style: ThixPolicy.titleStyle.copyWith(
                color: ThixPolicy.danger,
                fontWeight: ThixPolicy.bold,
              ),
            ),
          ),
        ]),
        content: Text(l10n.t('group_delete_message'), style: ThixPolicy.bodyStyle),
        actions: [
          TextButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.pop(ctx);
            },
            child: Text(l10n.t('cancel'), style: TextStyle(color: ThixPolicy.textMuted)),
          ),
          ElevatedButton(
            onPressed: () async {
              HapticFeedback.mediumImpact();
              Navigator.pop(ctx);
              await _deleteGroup();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: ThixPolicy.danger,
              foregroundColor: Colors.white,
            ),
            child: Text(l10n.t('delete')),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteGroup() async {
    final l10n = AppLocalizations.of(context);
    if (_isProcessing) return;

    setState(() => _isProcessing = true);
    debugPrint('[GroupInfo] 🗑️ Deleting group...');

    try {
      await _groupService.deleteGroup(widget.groupId);
      if (!mounted) return;
      Navigator.pop(context);
      _showSuccess(l10n.t('group_deleted'));
      debugPrint('[GroupInfo] ✓ Group deleted');
    } catch (e) {
      debugPrint('[GroupInfo] ❌ Delete error: $e');
      if (!mounted) return;
      _showError(_GroupInfoValidators.friendlyError(e, l10n));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ── MEMBER ACTIONS ────────────────────────────────────────────────────────

  void _showMemberActions(String userId) {
    final l10n = AppLocalizations.of(context);
    final member = _groupInfo?.getMember(userId);
    if (member == null) return;

    final memberIsAdmin = member.isAdmin;
    final isSelf = userId == _currentUserId;

    HapticFeedback.selectionClick();

    showModalBottomSheet(
      context: context,
      backgroundColor: ThixPolicy.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: ThixPolicy.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: CircleAvatar(
                radius: 18,
                backgroundColor: ThixPolicy.surfaceSoft,
                backgroundImage: member.avatarUrl != null ? NetworkImage(member.avatarUrl!) : null,
                child: member.avatarUrl == null
                    ? Text(
                        _GroupInfoValidators.safeInitial(member.displayName),
                        style: TextStyle(color: ThixPolicy.primary, fontWeight: FontWeight.bold),
                      )
                    : null,
              ),
              title: Text(
                _GroupInfoValidators.sanitize(member.displayName, maxLength: _kMaxDisplayNameLength),
                style: ThixPolicy.bodyStyle.copyWith(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                memberIsAdmin ? l10n.t('group_role_admin') : l10n.t('group_role_member'),
                style: TextStyle(color: memberIsAdmin ? ThixPolicy.gold : ThixPolicy.textMuted),
              ),
            ),
            const Divider(),

            // Promouvoir admin
            if (!memberIsAdmin && !isSelf && _isAdmin)
              Semantics(
                button: true,
                label: l10n.t('group_promote_admin'),
                child: ListTile(
                  leading: Icon(Icons.star_rounded, color: ThixPolicy.gold),
                  title: Text(l10n.t('group_promote_admin')),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _promoteToAdmin(userId);
                  },
                ),
              ),

            // Rétrograder
            if (memberIsAdmin && !isSelf && _isAdmin)
              Semantics(
                button: true,
                label: l10n.t('group_demote_member'),
                child: ListTile(
                  leading: Icon(Icons.star_border_rounded, color: ThixPolicy.textMuted),
                  title: Text(l10n.t('group_demote_member')),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _demoteFromAdmin(userId);
                  },
                ),
              ),

            // Retirer du groupe
            if (!isSelf && _isAdmin)
              Semantics(
                button: true,
                label: l10n.t('group_remove_member'),
                child: ListTile(
                  leading: Icon(Icons.remove_circle_outline, color: ThixPolicy.danger),
                  title: Text(
                    l10n.t('group_remove_member'),
                    style: TextStyle(color: ThixPolicy.danger),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _confirmRemoveMember(userId);
                  },
                ),
              ),

            // Voir le profil
            Semantics(
              button: true,
              label: l10n.t('group_view_profile'),
              child: ListTile(
                leading: Icon(Icons.person_outline_rounded, color: ThixPolicy.primary),
                title: Text(l10n.t('group_view_profile')),
                onTap: () {
                  Navigator.pop(ctx);
                  _showInfo(l10n.t('group_view_profile_coming_soon'));
                },
              ),
            ),

            // Fermer
            Semantics(
              button: true,
              label: l10n.t('close'),
              child: ListTile(
                leading: Icon(Icons.close, color: ThixPolicy.textMuted),
                title: Text(l10n.t('close')),
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.pop(ctx);
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _promoteToAdmin(String userId) async {
    final l10n = AppLocalizations.of(context);
    if (_isProcessing) return;

    setState(() => _isProcessing = true);
    debugPrint('[GroupInfo] ⭐ Promoting member to admin: $userId');

    try {
      await _groupService.promoteToAdmin(widget.groupId, userId);
      if (!mounted) return;
      await _loadData();
      _showSuccess(l10n.t('group_promoted_success'));
      debugPrint('[GroupInfo] ✓ Member promoted');
    } catch (e) {
      debugPrint('[GroupInfo] ❌ Promote error: $e');
      if (!mounted) return;
      _showError(_GroupInfoValidators.friendlyError(e, l10n));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _demoteFromAdmin(String userId) async {
    final l10n = AppLocalizations.of(context);
    if (_isProcessing) return;

    setState(() => _isProcessing = true);
    debugPrint('[GroupInfo] ⭐ Demoting admin: $userId');

    try {
      await _groupService.demoteFromAdmin(widget.groupId, userId);
      if (!mounted) return;
      await _loadData();
      _showSuccess(l10n.t('group_demoted_success'));
      debugPrint('[GroupInfo] ✓ Admin demoted');
    } catch (e) {
      debugPrint('[GroupInfo] ❌ Demote error: $e');
      if (!mounted) return;
      _showError(_GroupInfoValidators.friendlyError(e, l10n));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _confirmRemoveMember(String userId) {
    final l10n = AppLocalizations.of(context);

    HapticFeedback.mediumImpact();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThixPolicy.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(Icons.remove_circle_outline, color: ThixPolicy.danger, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l10n.t('group_remove_member_title'),
              style: ThixPolicy.titleStyle.copyWith(
                color: ThixPolicy.danger,
                fontWeight: ThixPolicy.bold,
              ),
            ),
          ),
        ]),
        content: Text(l10n.t('group_remove_member_message'), style: ThixPolicy.bodyStyle),
        actions: [
          TextButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.pop(ctx);
            },
            child: Text(l10n.t('cancel'), style: TextStyle(color: ThixPolicy.textMuted)),
          ),
          ElevatedButton(
            onPressed: () async {
              HapticFeedback.mediumImpact();
              Navigator.pop(ctx);
              await _removeMember(userId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: ThixPolicy.danger,
              foregroundColor: Colors.white,
            ),
            child: Text(l10n.t('group_remove_button')),
          ),
        ],
      ),
    );
  }

  Future<void> _removeMember(String userId) async {
    final l10n = AppLocalizations.of(context);
    if (_isProcessing) return;

    setState(() => _isProcessing = true);
    debugPrint('[GroupInfo] 🚫 Removing member: $userId');

    try {
      await _groupService.removeMember(widget.groupId, userId);
      if (!mounted) return;
      await _loadData();
      _showSuccess(l10n.t('group_member_removed'));
      debugPrint('[GroupInfo] ✓ Member removed');
    } catch (e) {
      debugPrint('[GroupInfo] ❌ Remove member error: $e');
      if (!mounted) return;
      _showError(_GroupInfoValidators.friendlyError(e, l10n));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ── ADD MEMBERS ───────────────────────────────────────────────────────────

  void _addMembers() {
    final l10n = AppLocalizations.of(context);
    HapticFeedback.selectionClick();
    debugPrint('[GroupInfo] ➕ Add members requested (not implemented)');
    _showInfo(l10n.t('group_add_members_coming_soon'));
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: ThixPolicy.surfaceSoft,
        appBar: AppBar(
          backgroundColor: ThixPolicy.primary,
          foregroundColor: Colors.white,
          title: Text(l10n.t('group_info_title')),
          leading: Semantics(
            button: true,
            label: l10n.t('back'),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () {
                HapticFeedback.selectionClick();
                Navigator.pop(context);
              },
            ),
          ),
        ),
        body: Center(child: CircularProgressIndicator(color: ThixPolicy.primary)),
      );
    }

    if (_conversation == null) {
      return Scaffold(
        backgroundColor: ThixPolicy.surfaceSoft,
        appBar: AppBar(
          backgroundColor: ThixPolicy.primary,
          foregroundColor: Colors.white,
          title: Text(l10n.t('group_info_title')),
          leading: Semantics(
            button: true,
            label: l10n.t('back'),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () {
                HapticFeedback.selectionClick();
                Navigator.pop(context);
              },
            ),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.group_off_rounded, size: 64, color: ThixPolicy.textMuted),
              const SizedBox(height: 16),
              Text(
                l10n.t('group_not_found_title'),
                style: ThixPolicy.titleStyle.copyWith(
                  fontSize: 18,
                  fontWeight: ThixPolicy.bold,
                  color: ThixPolicy.textMain,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  l10n.t('group_not_found_message'),
                  textAlign: TextAlign.center,
                  style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textMuted),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return _buildContent(l10n);
  }

  Widget _buildContent(AppLocalizations l10n) {
    final conv = _conversation!;
    final members = _groupInfo?.members ?? [];
    final onlineCount = members.where((m) => m.isOnline).length;
    final isAdmin = _isAdmin;
    final safeDisplayName = _GroupInfoValidators.sanitize(conv.displayName, maxLength: _kMaxDisplayNameLength);
    final safeGroupName = _GroupInfoValidators.sanitize(conv.groupName, maxLength: _kMaxDisplayNameLength);

    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      appBar: AppBar(
        backgroundColor: ThixPolicy.primary,
        elevation: 0,
        title: Text(
          l10n.t('group_info_title'),
          style: ThixPolicy.titleStyle.copyWith(
            color: Colors.white,
            fontWeight: ThixPolicy.bold,
          ),
        ),
        leading: Semantics(
          button: true,
          label: l10n.t('back'),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () {
              HapticFeedback.selectionClick();
              Navigator.pop(context);
            },
          ),
        ),
        actions: [
          if (isAdmin)
            Semantics(
              button: true,
              label: l10n.t('settings'),
              child: IconButton(
                icon: const Icon(Icons.settings_rounded, color: Colors.white),
                onPressed: _isProcessing ? null : _navigateToSettings,
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── En-tête du groupe ──
            _buildHeader(l10n, conv, safeDisplayName, onlineCount, members.length, isAdmin),
            const SizedBox(height: 24),
            Divider(height: 1, color: ThixPolicy.border),
            const SizedBox(height: 16),

            // ── Description ──
            if (safeGroupName != null && safeGroupName != safeDisplayName) ...[
              _buildDescription(l10n, safeGroupName),
              const SizedBox(height: 16),
              Divider(height: 1, color: ThixPolicy.border),
              const SizedBox(height: 16),
            ],

            // ── Code d'invitation ──
            if (_groupInfo?.inviteCode != null && _groupInfo!.inviteCode!.isNotEmpty) ...[
              _buildInviteCode(l10n, _groupInfo!.inviteCode!),
              const SizedBox(height: 16),
              Divider(height: 1, color: ThixPolicy.border),
              const SizedBox(height: 16),
            ],

            // ── Membres ──
            _buildMembersSection(l10n, members, isAdmin),
            const SizedBox(height: 24),

            // ── Actions ──
            _buildActions(l10n, isAdmin),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    AppLocalizations l10n,
    ChatConversation conv,
    String displayName,
    int onlineCount,
    int totalCount,
    bool isAdmin,
  ) {
    return RepaintBoundary(
      child: Center(
        child: Column(
          children: [
            Semantics(
              label: '${l10n.t('group_avatar')} $displayName',
              child: CircleAvatar(
                radius: _kAvatarRadius,
                backgroundColor: ThixPolicy.surfaceSoft,
                backgroundImage: conv.groupAvatar != null ? NetworkImage(conv.groupAvatar!) : null,
                child: conv.groupAvatar == null
                    ? Text(
                        _GroupInfoValidators.safeInitial(displayName),
                        style: TextStyle(
                          fontSize: _kAvatarInitialFontSize,
                          fontWeight: FontWeight.bold,
                          color: ThixPolicy.primary,
                        ),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              displayName.isEmpty ? l10n.t('group_default_name') : displayName,
              style: ThixPolicy.headlineStyle.copyWith(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: ThixPolicy.textMain,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              '$onlineCount ${l10n.t('group_online')} • $totalCount ${l10n.t('group_members')}',
              style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textMuted),
            ),
            const SizedBox(height: 16),
            if (isAdmin)
              Semantics(
                button: true,
                label: l10n.t('group_manage_button'),
                enabled: !_isProcessing,
                child: ElevatedButton.icon(
                  onPressed: _isProcessing ? null : _navigateToSettings,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ThixPolicy.gold,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  icon: const Icon(Icons.edit_rounded),
                  label: Text(l10n.t('group_manage_button')),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDescription(AppLocalizations l10n, String description) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.t('group_description_label'),
          style: ThixPolicy.labelStyle.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: ThixPolicy.textMain,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          description,
          style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textMuted),
        ),
      ],
    );
  }

  Widget _buildInviteCode(AppLocalizations l10n, String code) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.t('group_invite_code_label'),
          style: ThixPolicy.labelStyle.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: ThixPolicy.textMain,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: ThixPolicy.card,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ThixPolicy.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  code,
                  style: TextStyle(
                    fontSize: _kCodeFontSize,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: ThixPolicy.textMain,
                  ),
                ),
              ),
              Semantics(
                button: true,
                label: l10n.t('group_copy_code'),
                child: IconButton(
                  icon: Icon(Icons.copy_rounded, color: ThixPolicy.primary, size: 18),
                  onPressed: _copyInviteCode,
                  tooltip: l10n.t('group_copy_code'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMembersSection(AppLocalizations l10n, List<GroupMember> members, bool isAdmin) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${l10n.t('group_members')} (${members.length})',
              style: ThixPolicy.labelStyle.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: ThixPolicy.textMain,
              ),
            ),
            if (isAdmin)
              Semantics(
                button: true,
                label: l10n.t('group_add_members'),
                enabled: !_isProcessing,
                child: TextButton.icon(
                  onPressed: _isProcessing ? null : _addMembers,
                  icon: Icon(Icons.add_circle_rounded, size: 18, color: ThixPolicy.primary),
                  label: Text(
                    l10n.t('group_add_members'),
                    style: TextStyle(color: ThixPolicy.primary),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        GroupMemberList(
          members: members,
          showOnlineStatus: true,
          showRoles: true,
          onMemberTap: (userId) {
            _showMemberActions(userId);
          },
          onMemberLongPress: isAdmin && !_isProcessing
              ? (userId) => _showMemberActions(userId)
              : null,
        ),
      ],
    );
  }

  Widget _buildActions(AppLocalizations l10n, bool isAdmin) {
    if (isAdmin) {
      return Semantics(
        button: true,
        label: l10n.t('group_delete_button'),
        enabled: !_isProcessing,
        child: SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _isProcessing ? null : _showDeleteGroupDialog,
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: ThixPolicy.danger),
              foregroundColor: ThixPolicy.danger,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon: const Icon(Icons.delete_rounded),
            label: Text(l10n.t('group_delete_button')),
          ),
        ),
      );
    }

    return Semantics(
      button: true,
      label: l10n.t('group_leave_button'),
      enabled: !_isProcessing,
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _isProcessing ? null : _showLeaveGroupDialog,
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: ThixPolicy.danger),
            foregroundColor: ThixPolicy.danger,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          icon: const Icon(Icons.exit_to_app_rounded),
          label: Text(l10n.t('group_leave_button')),
        ),
      ),
    );
  }
}
