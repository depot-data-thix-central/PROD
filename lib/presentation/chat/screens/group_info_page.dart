// lib/presentation/chat/screens/group_info_page.dart
//
// ============================================================================
// GROUP INFO PAGE — Production Enterprise++ (ROUTE PARAMÈTRES RESTAURÉE)
// ============================================================================
// ✅ FIX : icône ⚙️ AppBar + bouton doré "Gérer" → GroupSettingsPage
// ✅ FIX : _tr() fallback FR sur TOUTES les clés (plus de libellés bruts)
// ✅ Ajout membres fonctionnel (sheet recherche + multi-sélection)
// ============================================================================

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/models/chat/group_info.dart';
import 'package:thix_id/presentation/chat/group/group_badge.dart';
import 'package:thix_id/presentation/chat/group/group_member_list.dart';
import 'package:thix_id/services/chat/chat_service.dart';
import 'package:thix_id/services/chat/group_service.dart';
import 'package:thix_id/presentation/chat/screens/group_settings_page.dart';

const double _kAvatarRadius = 60.0;
const double _kAvatarInitialFontSize = 36.0;
const double _kCodeFontSize = 16.0;
const int _kMaxDisplayNameLength = 100;

/// l10n avec repli FR : plus JAMAIS de clé brute affichée.
String _tr(AppLocalizations l10n, String key, String fallback) {
  final s = l10n.t(key);
  return s == key ? fallback : s;
}

class _GroupInfoValidators {
  _GroupInfoValidators._();

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

  static String safeInitial(String? name) {
    if (name == null || name.trim().isEmpty) return '?';
    return name.trim()[0].toUpperCase();
  }

  static String friendlyError(dynamic e, AppLocalizations l10n) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('not admin') || msg.contains('permission')) {
      return _tr(l10n, 'group_error_not_admin', 'Réservé aux administrateurs');
    }
    if (msg.contains('not found')) {
      return _tr(l10n, 'group_error_not_found', 'Groupe introuvable');
    }
    if (msg.contains('network') || msg.contains('timeout')) {
      return _tr(l10n, 'group_error_network', 'Erreur réseau');
    }
    if (msg.contains('last admin') || msg.contains('last owner')) {
      return _tr(l10n, 'group_error_last_admin', 'Impossible de retirer le dernier admin');
    }
    return _tr(l10n, 'group_error_generic', 'Une erreur est survenue');
  }
}

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
  bool _isLoading = true;
  bool _isProcessing = false;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _groupService = GroupService(Supabase.instance.client);
    _chatService = ChatService(Supabase.instance.client);
    _currentUserId = _chatService.currentUserId;
    _loadData();
  }

  // ── FEEDBACK ──
  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(message)),
      ]),
      backgroundColor: ThixPolicy.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  void _showError(String message) {
    if (!mounted) return;
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.error_outline_rounded, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(message)),
      ]),
      backgroundColor: ThixPolicy.danger,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  void _showInfo(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.info_outline_rounded, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(message)),
      ]),
      backgroundColor: ThixPolicy.primary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  Future<void> _loadData() async {
    final l10n = AppLocalizations.of(context);
    if (_currentUserId == null) {
      setState(() => _isLoading = false);
      _showError(_tr(l10n, 'group_error_no_user', 'Session expirée'));
      return;
    }
    setState(() => _isLoading = true);
    try {
      final groupInfo = await _groupService.getGroupInfo(widget.groupId);
      if (!mounted) return;
      setState(() {
        _groupInfo = groupInfo;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError(_GroupInfoValidators.friendlyError(e, l10n));
    }
  }

  bool get _isAdmin {
    if (_currentUserId == null || _groupInfo == null) return false;
    return _groupInfo!.isAdmin(_currentUserId!);
  }

  // ── ✅ ROUTE RESTAURÉE : Paramètres / Gérer le groupe ──
  void _navigateToSettings() {
    HapticFeedback.selectionClick();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => GroupSettingsPage(groupId: widget.groupId)),
    ).then((_) {
      if (mounted) _loadData();
    });
  }

  void _copyInviteCode() {
    final l10n = AppLocalizations.of(context);
    final code = _groupInfo?.inviteCode;
    if (code == null || code.isEmpty) {
      _showInfo(_tr(l10n, 'group_no_invite_code', 'Aucun code d’invitation'));
      return;
    }
    HapticFeedback.selectionClick();
    Clipboard.setData(ClipboardData(text: code));
    _showSuccess(_tr(l10n, 'group_code_copied', 'Code copié'));
  }

  Future<void> _exportMembersCSV() async {
    final l10n = AppLocalizations.of(context);
    if (!_isAdmin) {
      _showError(_tr(l10n, 'group_error_not_admin', 'Réservé aux administrateurs'));
      return;
    }
    HapticFeedback.mediumImpact();
    try {
      final csv = await _groupService.exportMembersToCSV(widget.groupId);
      await Clipboard.setData(ClipboardData(text: csv));
      _showSuccess(_tr(l10n, 'group_export_success', 'Export CSV copié'));
    } catch (e) {
      if (!mounted) return;
      _showError(_GroupInfoValidators.friendlyError(e, l10n));
    }
  }

  // ── AJOUT MEMBRES (fonctionnel) ──
  void _addMembers() {
    final l10n = AppLocalizations.of(context);
    if (!_isAdmin) {
      _showError(_tr(l10n, 'group_error_not_admin', 'Réservé aux administrateurs'));
      return;
    }
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _AddMembersSheet(
        service: _groupService,
        groupId: widget.groupId,
        onConfirm: (ids) async {
          final ok = await _groupService.addMembers(widget.groupId, ids);
          if (!mounted) return;
          await _loadData();
          if (ok > 0) {
            _showSuccess(_tr(l10n, 'group_members_added', '$ok membre(s) ajouté(s)'));
          } else {
            _showError(_tr(l10n, 'group_members_added_none', 'Aucun membre ajouté'));
          }
        },
      ),
    );
  }

  // ── QUITTER / SUPPRIMER ──
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
          Expanded(child: Text(_tr(l10n, 'group_leave_title', 'Quitter le groupe ?'),
              style: ThixPolicy.titleStyle.copyWith(color: ThixPolicy.danger, fontWeight: ThixPolicy.bold))),
        ]),
        content: Text(_tr(l10n, 'group_leave_message', 'Vous perdrez l’accès à l’historique.'), style: ThixPolicy.bodyStyle),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(_tr(l10n, 'cancel', 'Annuler'))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _leaveGroup();
            },
            style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.danger, foregroundColor: Colors.white),
            child: Text(_tr(l10n, 'group_leave_button', 'Quitter')),
          ),
        ],
      ),
    );
  }

  Future<void> _leaveGroup() async {
    final l10n = AppLocalizations.of(context);
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      await _groupService.leaveGroup(widget.groupId);
      if (!mounted) return;
      Navigator.pop(context);
      _showSuccess(_tr(l10n, 'group_left_success', 'Vous avez quitté le groupe'));
    } catch (e) {
      if (!mounted) return;
      _showError(_GroupInfoValidators.friendlyError(e, l10n));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

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
          Expanded(child: Text(_tr(l10n, 'group_delete_title', 'Supprimer le groupe ?'),
              style: ThixPolicy.titleStyle.copyWith(color: ThixPolicy.danger, fontWeight: ThixPolicy.bold))),
        ]),
        content: Text(_tr(l10n, 'group_delete_message', 'Action irréversible pour tous les membres.'), style: ThixPolicy.bodyStyle),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(_tr(l10n, 'cancel', 'Annuler'))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _deleteGroup();
            },
            style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.danger, foregroundColor: Colors.white),
            child: Text(_tr(l10n, 'delete', 'Supprimer')),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteGroup() async {
    final l10n = AppLocalizations.of(context);
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      await _groupService.deleteGroup(widget.groupId);
      if (!mounted) return;
      Navigator.pop(context);
      _showSuccess(_tr(l10n, 'group_deleted', 'Groupe supprimé'));
    } catch (e) {
      if (!mounted) return;
      _showError(_GroupInfoValidators.friendlyError(e, l10n));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ── ACTIONS MEMBRE ──
  void _showMemberActions(String userId) {
    final l10n = AppLocalizations.of(context);
    final member = _groupInfo?.getMember(userId);
    if (member == null) return;
    final isSelf = userId == _currentUserId;
    HapticFeedback.selectionClick();

    showModalBottomSheet(
      context: context,
      backgroundColor: ThixPolicy.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: ThixPolicy.border, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 8),
            ListTile(
              leading: CircleAvatar(
                radius: 18,
                backgroundColor: ThixPolicy.surfaceSoft,
                backgroundImage: member.avatarUrl != null ? CachedNetworkImageProvider(member.avatarUrl!) : null,
                child: member.avatarUrl == null
                    ? Text(_GroupInfoValidators.safeInitial(member.displayName),
                        style: TextStyle(color: ThixPolicy.primary, fontWeight: FontWeight.bold))
                    : null,
              ),
              title: Text(_GroupInfoValidators.sanitize(member.displayName, maxLength: _kMaxDisplayNameLength),
                  style: ThixPolicy.bodyStyle.copyWith(fontWeight: FontWeight.w600)),
              subtitle: GroupBadge(role: member.role, isCompact: true),
            ),
            const Divider(),
            ListTile(
              leading: Icon(Icons.person_outline_rounded, color: ThixPolicy.primary),
              title: Text(_tr(l10n, 'group_view_profile', 'Voir le profil')),
              onTap: () {
                Navigator.pop(ctx);
                _showInfo(_tr(l10n, 'group_view_profile_coming_soon', 'Profil bientôt disponible'));
              },
            ),
            if (!member.hasPrivileges && !isSelf && _isAdmin)
              ListTile(
                leading: Icon(Icons.star_rounded, color: ThixPolicy.gold),
                title: Text(_tr(l10n, 'group_promote_admin', 'Promouvoir admin')),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _changeMemberRole(userId, GroupRole.admin);
                },
              ),
            if (member.isAdmin && !member.isOwner && !isSelf && _isAdmin)
              ListTile(
                leading: Icon(Icons.star_border_rounded, color: ThixPolicy.textMuted),
                title: Text(_tr(l10n, 'group_demote_member', 'Rétrograder membre')),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _changeMemberRole(userId, GroupRole.member);
                },
              ),
            if (!member.isMuted && !isSelf && _isAdmin)
              ListTile(
                leading: Icon(Icons.volume_off_rounded, color: ThixPolicy.warning),
                title: Text(_tr(l10n, 'group_mute_member', 'Mettre en sourdine')),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _muteMember(userId);
                },
              ),
            if (member.isMuted && !isSelf && _isAdmin)
              ListTile(
                leading: Icon(Icons.volume_up_rounded, color: ThixPolicy.success),
                title: Text(_tr(l10n, 'group_unmute_member', 'Réactiver')),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _unmuteMember(userId);
                },
              ),
            if (!isSelf && _isAdmin)
              ListTile(
                leading: Icon(Icons.remove_circle_outline, color: ThixPolicy.danger),
                title: Text(_tr(l10n, 'group_remove_member', 'Retirer du groupe'),
                    style: TextStyle(color: ThixPolicy.danger)),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmRemoveMember(userId);
                },
              ),
            ListTile(
              leading: Icon(Icons.close, color: ThixPolicy.textMuted),
              title: Text(_tr(l10n, 'close', 'Fermer')),
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.pop(ctx);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _changeMemberRole(String userId, GroupRole newRole) async {
    final l10n = AppLocalizations.of(context);
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      await _groupService.changeMemberRole(widget.groupId, userId, newRole);
      if (!mounted) return;
      await _loadData();
      _showSuccess(_tr(l10n, 'group_role_changed', 'Rôle mis à jour'));
    } catch (e) {
      if (!mounted) return;
      _showError(_GroupInfoValidators.friendlyError(e, l10n));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _muteMember(String userId) async {
    final l10n = AppLocalizations.of(context);
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      await _groupService.muteMember(widget.groupId, userId, duration: const Duration(days: 7));
      if (!mounted) return;
      await _loadData();
      _showSuccess(_tr(l10n, 'group_member_muted', 'Membre mis en sourdine'));
    } catch (e) {
      if (!mounted) return;
      _showError(_GroupInfoValidators.friendlyError(e, l10n));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _unmuteMember(String userId) async {
    final l10n = AppLocalizations.of(context);
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      await _groupService.unmuteMember(widget.groupId, userId);
      if (!mounted) return;
      await _loadData();
      _showSuccess(_tr(l10n, 'group_member_unmuted', 'Membre réactivé'));
    } catch (e) {
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
          Expanded(child: Text(_tr(l10n, 'group_remove_member_title', 'Retirer ce membre ?'),
              style: ThixPolicy.titleStyle.copyWith(color: ThixPolicy.danger, fontWeight: ThixPolicy.bold))),
        ]),
        content: Text(_tr(l10n, 'group_remove_member_message', 'Il perdra l’accès au groupe.'), style: ThixPolicy.bodyStyle),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(_tr(l10n, 'cancel', 'Annuler'))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _removeMember(userId);
            },
            style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.danger, foregroundColor: Colors.white),
            child: Text(_tr(l10n, 'group_remove_button', 'Retirer')),
          ),
        ],
      ),
    );
  }

  Future<void> _removeMember(String userId) async {
    final l10n = AppLocalizations.of(context);
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      await _groupService.removeMember(widget.groupId, userId);
      if (!mounted) return;
      await _loadData();
      _showSuccess(_tr(l10n, 'group_member_removed', 'Membre retiré'));
    } catch (e) {
      if (!mounted) return;
      _showError(_GroupInfoValidators.friendlyError(e, l10n));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ── BUILD ──
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: ThixPolicy.surfaceSoft,
        appBar: AppBar(
          backgroundColor: ThixPolicy.primary,
          foregroundColor: Colors.white,
          title: Text(_tr(l10n, 'group_info_title', 'Infos du groupe')),
          leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => Navigator.pop(context)),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_groupInfo == null) {
      return Scaffold(
        backgroundColor: ThixPolicy.surfaceSoft,
        appBar: AppBar(
          backgroundColor: ThixPolicy.primary,
          foregroundColor: Colors.white,
          title: Text(_tr(l10n, 'group_info_title', 'Infos du groupe')),
          leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => Navigator.pop(context)),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.group_off_rounded, size: 64, color: ThixPolicy.textMuted),
              const SizedBox(height: 16),
              Text(_tr(l10n, 'group_not_found_title', 'Groupe introuvable'),
                  style: ThixPolicy.titleStyle.copyWith(fontSize: 18, fontWeight: ThixPolicy.bold)),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(_tr(l10n, 'group_not_found_message', 'Ce groupe n’existe plus ou vous n’y avez pas accès.'),
                    textAlign: TextAlign.center, style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textMuted)),
              ),
            ],
          ),
        ),
      );
    }

    return _buildContent(l10n);
  }

  Widget _buildContent(AppLocalizations l10n) {
    final groupInfo = _groupInfo!;
    final members = groupInfo.members;
    final isAdmin = _isAdmin;
    final safeDisplayName = _GroupInfoValidators.sanitize(groupInfo.name, maxLength: _kMaxDisplayNameLength);

    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      appBar: AppBar(
        backgroundColor: ThixPolicy.primary,
        elevation: 0,
        title: Text(
          _tr(l10n, 'group_info_title', 'Infos du groupe'),
          style: ThixPolicy.titleStyle.copyWith(color: Colors.white, fontWeight: ThixPolicy.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () {
            HapticFeedback.selectionClick();
            Navigator.pop(context);
          },
        ),
        // ✅ RESTAURÉ : icône Paramètres (admin uniquement)
        actions: [
          if (isAdmin)
            Semantics(
              button: true,
              label: _tr(l10n, 'settings', 'Paramètres'),
              child: IconButton(
                icon: const Icon(Icons.settings_rounded, color: Colors.white),
                onPressed: _isProcessing ? null : _navigateToSettings,
                tooltip: _tr(l10n, 'settings', 'Paramètres'),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(l10n, groupInfo, safeDisplayName, isAdmin),
            const SizedBox(height: 24),
            _buildStatistics(l10n, groupInfo),
            const SizedBox(height: 24),
            const Divider(height: 1),
            const SizedBox(height: 16),
            if (groupInfo.description != null && groupInfo.description!.isNotEmpty) ...[
              _buildDescription(l10n, groupInfo.description!),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),
            ],
            if (groupInfo.inviteCode != null && groupInfo.inviteCode!.isNotEmpty) ...[
              _buildInviteCode(l10n, groupInfo.inviteCode!),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),
            ],
            _buildMembersSection(l10n, members, isAdmin),
            const SizedBox(height: 24),
            _buildActions(l10n, isAdmin),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(AppLocalizations l10n, GroupInfo groupInfo, String displayName, bool isAdmin) {
    return Center(
      child: Column(
        children: [
          CircleAvatar(
            radius: _kAvatarRadius,
            backgroundColor: ThixPolicy.surfaceSoft,
            backgroundImage: groupInfo.avatarUrl != null ? CachedNetworkImageProvider(groupInfo.avatarUrl!) : null,
            child: groupInfo.avatarUrl == null
                ? Text(_GroupInfoValidators.safeInitial(displayName),
                    style: TextStyle(fontSize: _kAvatarInitialFontSize, fontWeight: FontWeight.bold, color: ThixPolicy.primary))
                : null,
          ),
          const SizedBox(height: 12),
          Text(
            displayName.isEmpty ? _tr(l10n, 'group_default_name', 'Groupe') : displayName,
            style: ThixPolicy.titleStyle.copyWith(fontSize: 22, fontWeight: FontWeight.bold, color: ThixPolicy.textMain),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            '${groupInfo.onlineCount} ${_tr(l10n, 'group_online', 'en ligne')} • '
            '${groupInfo.memberCount} ${_tr(l10n, 'group_members', 'membres')}',
            style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textMuted),
          ),
          // ✅ RESTAURÉ : bouton doré "Gérer le groupe"
          if (isAdmin) ...[
            const SizedBox(height: 16),
            Semantics(
              button: true,
              label: _tr(l10n, 'group_manage_button', 'Gérer le groupe'),
              enabled: !_isProcessing,
              child: ElevatedButton.icon(
                onPressed: _isProcessing ? null : _navigateToSettings,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ThixPolicy.gold,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                icon: const Icon(Icons.edit_rounded),
                label: Text(_tr(l10n, 'group_manage_button', 'Gérer le groupe')),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatistics(AppLocalizations l10n, GroupInfo groupInfo) {
    final newMembers = groupInfo.newMemberCount;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ThixPolicy.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ThixPolicy.primary.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_tr(l10n, 'group_statistics_title', 'Statistiques du groupe'),
              style: ThixPolicy.titleStyle.copyWith(fontWeight: ThixPolicy.bold, fontSize: 14)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(Icons.people_alt_rounded, '${groupInfo.memberCount}',
                  _tr(l10n, 'group_stat_total', 'Total'), ThixPolicy.primary),
              _buildStatItem(Icons.circle, '${groupInfo.onlineCount}',
                  _tr(l10n, 'group_stat_online', 'En ligne'), ThixPolicy.success),
              _buildStatItem(Icons.fiber_new_rounded, '$newMembers',
                  _tr(l10n, 'group_stat_new', 'Nouveaux'), ThixPolicy.gold),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label, Color color) {
    return Column(children: [
      Icon(icon, size: 20, color: color),
      const SizedBox(height: 4),
      Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
      Text(label, style: TextStyle(fontSize: 10, color: ThixPolicy.textMuted, fontWeight: FontWeight.w500)),
    ]);
  }

  Widget _buildDescription(AppLocalizations l10n, String description) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_tr(l10n, 'group_description_label', 'Description'),
            style: ThixPolicy.labelStyle.copyWith(fontSize: 16, fontWeight: FontWeight.w700, color: ThixPolicy.textMain)),
        const SizedBox(height: 6),
        Text(description, style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textMuted)),
      ],
    );
  }

  Widget _buildInviteCode(AppLocalizations l10n, String code) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_tr(l10n, 'group_invite_code_label', 'Code d’invitation'),
            style: ThixPolicy.labelStyle.copyWith(fontSize: 16, fontWeight: FontWeight.w700, color: ThixPolicy.textMain)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: ThixPolicy.card, borderRadius: BorderRadius.circular(8), border: Border.all(color: ThixPolicy.border)),
          child: Row(
            children: [
              Expanded(
                child: Text(code,
                    style: TextStyle(fontSize: _kCodeFontSize, fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()], color: ThixPolicy.textMain, letterSpacing: 1.5)),
              ),
              IconButton(
                icon: Icon(Icons.copy_rounded, color: ThixPolicy.primary, size: 18),
                onPressed: _copyInviteCode,
                tooltip: _tr(l10n, 'group_copy_code', 'Copier le code'),
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
            Text('${_tr(l10n, 'group_members', 'Membres')} (${members.length})',
                style: ThixPolicy.labelStyle.copyWith(fontSize: 16, fontWeight: FontWeight.w700, color: ThixPolicy.textMain)),
            Row(children: [
              if (isAdmin)
                IconButton(
                  icon: Icon(Icons.download_rounded, size: 18, color: ThixPolicy.primary),
                  onPressed: _isProcessing ? null : _exportMembersCSV,
                  tooltip: _tr(l10n, 'group_export_csv', 'Exporter (CSV)'),
                ),
              if (isAdmin)
                TextButton.icon(
                  onPressed: _isProcessing ? null : _addMembers,
                  icon: Icon(Icons.add_circle_rounded, size: 18, color: ThixPolicy.primary),
                  label: Text(_tr(l10n, 'group_add_members', 'Ajouter'), style: TextStyle(color: ThixPolicy.primary)),
                ),
            ]),
          ],
        ),
        const SizedBox(height: 8),
        GroupMemberList(
          members: members,
          currentUserId: _currentUserId ?? '',
          isCurrentUserAgent: false,
          showStatsHeader: false,
          showOnlineStatus: true,
          showRoles: true,
          onMemberTap: (userId) => _showMemberActions(userId),
          onMemberLongPress: isAdmin && !_isProcessing ? (userId) => _showMemberActions(userId) : null,
          onPromoteAdmin: isAdmin ? (userId) => _changeMemberRole(userId, GroupRole.admin) : null,
          onDemoteMember: isAdmin ? (userId) => _changeMemberRole(userId, GroupRole.member) : null,
          onRemoveMember: isAdmin ? (userId) => _confirmRemoveMember(userId) : null,
        ),
      ],
    );
  }

  Widget _buildActions(AppLocalizations l10n, bool isAdmin) {
    if (isAdmin) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _isProcessing ? null : _showDeleteGroupDialog,
          style: OutlinedButton.styleFrom(
              side: BorderSide(color: ThixPolicy.danger),
              foregroundColor: ThixPolicy.danger,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 14)),
          icon: const Icon(Icons.delete_rounded),
          label: Text(_tr(l10n, 'group_delete_button', 'Supprimer le groupe')),
        ),
      );
    }
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _isProcessing ? null : _showLeaveGroupDialog,
        style: OutlinedButton.styleFrom(
            side: BorderSide(color: ThixPolicy.danger),
            foregroundColor: ThixPolicy.danger,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(vertical: 14)),
        icon: const Icon(Icons.exit_to_app_rounded),
        label: Text(_tr(l10n, 'group_leave_button', 'Quitter le groupe')),
      ),
    );
  }
}

// ============================================================================
// SHEET AJOUT DE MEMBRES
// ============================================================================
class _AddMembersSheet extends StatefulWidget {
  final GroupService service;
  final String groupId;
  final Future<void> Function(List<String> ids) onConfirm;
  const _AddMembersSheet({required this.service, required this.groupId, required this.onConfirm});
  @override
  State<_AddMembersSheet> createState() => _AddMembersSheetState();
}

class _AddMembersSheetState extends State<_AddMembersSheet> {
  final _searchCtrl = TextEditingController();
  final Set<String> _selected = <String>{};
  List<GroupMember> _candidates = <GroupMember>[];
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await widget.service.searchUsersNotInGroup(widget.groupId, query: _searchCtrl.text, limit: 30);
    if (!mounted) return;
    setState(() {
      _candidates = list;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(color: ThixPolicy.card, borderRadius: const BorderRadius.vertical(top: Radius.circular(22))),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: ThixPolicy.border, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.person_add_alt_rounded, color: ThixPolicy.primary),
              const SizedBox(width: 8),
              Expanded(child: Text(_tr(l10n, 'group_add_members_title', 'Ajouter des membres'),
                  style: ThixPolicy.titleStyle.copyWith(fontWeight: ThixPolicy.bold))),
              Text('${_selected.length}', style: ThixPolicy.titleStyle.copyWith(color: ThixPolicy.primary, fontWeight: ThixPolicy.bold)),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _searchCtrl,
            onSubmitted: (_) => _load(),
            decoration: InputDecoration(
              hintText: _tr(l10n, 'group_search_contacts', 'Rechercher un contact…'),
              prefixIcon: const Icon(Icons.search_rounded, size: 20, color: ThixPolicy.textMuted),
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _candidates.isEmpty
                    ? Center(child: Text(_tr(l10n, 'group_no_candidates', 'Aucun contact disponible'),
                        style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textMuted)))
                    : ListView.builder(
                        itemCount: _candidates.length,
                        itemBuilder: (ctx, i) {
                          final m = _candidates[i];
                          final checked = _selected.contains(m.userId);
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: ThixPolicy.surfaceSoft,
                              backgroundImage: m.avatarUrl != null ? CachedNetworkImageProvider(m.avatarUrl!) : null,
                              child: m.avatarUrl == null
                                  ? Text(m.initial, style: TextStyle(color: ThixPolicy.primary, fontWeight: FontWeight.w600))
                                  : null,
                            ),
                            title: Text(m.displayName, style: ThixPolicy.bodyStyle.copyWith(fontWeight: FontWeight.w600)),
                            trailing: Icon(checked ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                                color: checked ? ThixPolicy.gold : ThixPolicy.textMuted),
                            onTap: () => setState(() {
                              if (checked) {
                                _selected.remove(m.userId);
                              } else {
                                _selected.add(m.userId);
                              }
                            }),
                          );
                        },
                      ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _selected.isEmpty ? ThixPolicy.border : ThixPolicy.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _selected.isEmpty || _saving
                  ? null
                  : () async {
                      setState(() => _saving = true);
                      Navigator.pop(context);
                      await widget.onConfirm(_selected.toList());
                    },
              icon: const Icon(Icons.person_add_alt_rounded),
              label: Text(_tr(l10n, 'group_add_confirm', 'Ajouter au groupe')),
            ),
          ),
        ],
      ),
    );
  }
}
