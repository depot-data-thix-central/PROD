// lib/presentation/chat/settings/group_settings_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/models/chat/group_info.dart';
import 'package:thix_id/presentation/chat/screens/group_info_page.dart';
import 'package:thix_id/services/chat/chat_service.dart';
import 'package:thix_id/services/chat/group_service.dart';

// ============================================================================
// CONSTANTS
// ============================================================================
const int _kMaxGroupNameLength = 100;
const int _kMaxDescriptionLength = 500;
const int _kMinGroupNameLength = 3;
const double _kAvatarRadius = 50.0;
const double _kCameraIconSize = 18.0;
const double _kCodeFontSize = 16.0;

// ============================================================================
// VALIDATORS
// ============================================================================
class _GroupValidators {
  _GroupValidators._();

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

  static bool isValidGroupName(String name) {
    return name.length >= _kMinGroupNameLength && name.length <= _kMaxGroupNameLength;
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
    return l10n.t('group_error_generic');
  }
}

// ============================================================================
// GROUP SETTINGS PAGE
// ============================================================================

/// Écran de paramètres du groupe (admin uniquement).
///
/// Permet de modifier :
/// - Nom du groupe
/// - Description
/// - Avatar (à venir)
/// - Code d'invitation
/// - Membres (via GroupInfoPage)
/// - Visibilité (public/privé)
/// - Suppression du groupe
class GroupSettingsPage extends StatefulWidget {
  final String groupId;

  const GroupSettingsPage({super.key, required this.groupId});

  @override
  State<GroupSettingsPage> createState() => _GroupSettingsPageState();
}

class _GroupSettingsPageState extends State<GroupSettingsPage> {
  late GroupService _groupService;
  late ChatService _chatService;
  GroupInfo? _groupInfo;
  bool _isLoading = true;
  bool _isSaving = false;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  String? _inviteCode;
  String? _currentUserId;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _groupService = GroupService(Supabase.instance.client);
    _chatService = ChatService(Supabase.instance.client);
    _currentUserId = _chatService.currentUserId;
    debugPrint('[GroupSettings] 🚀 Page opened for group: ${widget.groupId}');
    _loadData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    debugPrint('[GroupSettings] 👋 Page disposed');
    super.dispose();
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
      debugPrint('[GroupSettings] ❌ No current user ID');
      setState(() => _isLoading = false);
      _showError(l10n.t('group_error_no_user'));
      return;
    }

    setState(() => _isLoading = true);
    debugPrint('[GroupSettings] 🔄 Loading group data...');

    try {
      final conv = await _groupService.getGroupInfo(widget.groupId);
      final supabase = Supabase.instance.client;
      final info = await supabase
          .from('group_info')
          .select('*')
          .eq('group_id', widget.groupId)
          .maybeSingle();

      // Vérifier si l'utilisateur est admin
      final participants = await supabase
          .from('conversation_participants')
          .select('role')
          .eq('conversation_id', widget.groupId)
          .eq('user_id', _currentUserId!)
          .maybeSingle();

      _isAdmin = participants != null && participants['role'] == 'admin';

      if (!mounted) return;

      setState(() {
        _groupInfo = GroupInfo(
          groupId: widget.groupId,
          name: conv.groupName ?? '',
          avatarUrl: conv.groupAvatar,
          members: [],
          adminIds: [],
          isPublic: info?['is_public'] ?? false,
          inviteCode: info?['invite_code'],
          createdAt: conv.updatedAt,
        );
        _nameController.text = conv.groupName ?? '';
        _descController.text = info?['description'] ?? '';
        _inviteCode = info?['invite_code'];
        _isLoading = false;
      });

      debugPrint('[GroupSettings] ✓ Data loaded (isAdmin: $_isAdmin)');
    } catch (e) {
      debugPrint('[GroupSettings] ❌ Load error: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError(_GroupValidators.friendlyError(e, l10n));
    }
  }

  // ── SAVE CHANGES ──────────────────────────────────────────────────────────

  Future<void> _saveChanges() async {
    final l10n = AppLocalizations.of(context);

    if (_isSaving) {
      debugPrint('[GroupSettings] ⚠️ Save already in progress');
      return;
    }

    final name = _GroupValidators.sanitize(
      _nameController.text.trim(),
      maxLength: _kMaxGroupNameLength,
    );
    final description = _GroupValidators.sanitize(
      _descController.text.trim(),
      maxLength: _kMaxDescriptionLength,
    );

    if (!_GroupValidators.isValidGroupName(name)) {
      _showError(l10n.t('group_error_name_invalid'));
      return;
    }

    if (!_isAdmin) {
      _showError(l10n.t('group_error_not_admin'));
      return;
    }

    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();
    debugPrint('[GroupSettings] 💾 Saving changes...');

    try {
      await _groupService.updateGroupInfo(
        groupId: widget.groupId,
        name: name,
        description: description.isNotEmpty ? description : null,
        isPublic: _groupInfo?.isPublic,
      );

      if (!mounted) return;
      setState(() => _isSaving = false);
      _showSuccess(l10n.t('group_save_success'));
      debugPrint('[GroupSettings] ✓ Changes saved');
      Navigator.pop(context, true);
    } catch (e) {
      debugPrint('[GroupSettings] ❌ Save error: $e');
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showError(_GroupValidators.friendlyError(e, l10n));
    }
  }

  // ── REGENERATE INVITE CODE ────────────────────────────────────────────────

  Future<void> _regenerateInviteCode() async {
    final l10n = AppLocalizations.of(context);

    if (!_isAdmin) {
      _showError(l10n.t('group_error_not_admin'));
      return;
    }

    HapticFeedback.selectionClick();
    debugPrint('[GroupSettings] 🔄 Regenerating invite code...');

    try {
      final newCode = await _groupService.regenerateInviteCode(widget.groupId);

      if (!mounted) return;
      setState(() => _inviteCode = newCode);
      _showSuccess(l10n.t('group_invite_regenerated'));
      debugPrint('[GroupSettings] ✓ Invite code regenerated');
    } catch (e) {
      debugPrint('[GroupSettings] ❌ Regenerate error: $e');
      if (!mounted) return;
      _showError(_GroupValidators.friendlyError(e, l10n));
    }
  }

  // ── COPY INVITE CODE ──────────────────────────────────────────────────────

  void _copyInviteCode() {
    final l10n = AppLocalizations.of(context);

    if (_inviteCode == null || _inviteCode!.isEmpty) {
      _showInfo(l10n.t('group_no_invite_code'));
      return;
    }

    HapticFeedback.selectionClick();
    Clipboard.setData(ClipboardData(text: _inviteCode!));
    _showSuccess(l10n.t('group_code_copied'));
    debugPrint('[GroupSettings] 📋 Invite code copied');
  }

  // ── NAVIGATION ────────────────────────────────────────────────────────────

  void _navigateToGroupInfo() {
    HapticFeedback.selectionClick();
    debugPrint('[GroupSettings] ➡️ Navigating to GroupInfoPage');
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => GroupInfoPage(groupId: widget.groupId)),
    );
  }

  // ── CHANGE AVATAR ─────────────────────────────────────────────────────────

  void _changeAvatar() {
    final l10n = AppLocalizations.of(context);
    HapticFeedback.selectionClick();
    debugPrint('[GroupSettings] 📸 Change avatar requested (not implemented)');
    _showInfo(l10n.t('group_avatar_coming_soon'));
  }

  // ── DELETE GROUP ──────────────────────────────────────────────────────────

  void _showDeleteGroupDialog() {
    final l10n = AppLocalizations.of(context);

    if (!_isAdmin) {
      _showError(l10n.t('group_error_not_admin'));
      return;
    }

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
        content: Text(
          l10n.t('group_delete_message'),
          style: ThixPolicy.bodyStyle,
        ),
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

    debugPrint('[GroupSettings] 🗑️ Deleting group...');

    try {
      await _groupService.deleteGroup(widget.groupId);

      if (!mounted) return;
      Navigator.pop(context, true);
      _showSuccess(l10n.t('group_deleted'));
      debugPrint('[GroupSettings] ✓ Group deleted');
    } catch (e) {
      debugPrint('[GroupSettings] ❌ Delete error: $e');
      if (!mounted) return;
      _showError(_GroupValidators.friendlyError(e, l10n));
    }
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
          title: Text(l10n.t('group_settings_title')),
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

    if (!_isAdmin) {
      return _buildAccessDenied(l10n);
    }

    return _buildAdminView(l10n);
  }

  Widget _buildAccessDenied(AppLocalizations l10n) {
    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      appBar: AppBar(
        backgroundColor: ThixPolicy.primary,
        foregroundColor: Colors.white,
        title: Text(l10n.t('group_settings_title')),
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
            Icon(Icons.lock_rounded, size: 64, color: ThixPolicy.textMuted),
            const SizedBox(height: 16),
            Text(
              l10n.t('group_access_denied_title'),
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
                l10n.t('group_access_denied_message'),
                textAlign: TextAlign.center,
                style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminView(AppLocalizations l10n) {
    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      appBar: AppBar(
        backgroundColor: ThixPolicy.primary,
        elevation: 0,
        title: Text(
          l10n.t('group_settings_title'),
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
          _isSaving
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  ),
                )
              : Semantics(
                  button: true,
                  label: l10n.t('save'),
                  child: TextButton(
                    onPressed: _saveChanges,
                    child: Text(
                      l10n.t('save'),
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Avatar ──
            _buildAvatarSection(l10n),
            const SizedBox(height: 24),
            Divider(height: 1, color: ThixPolicy.border),
            const SizedBox(height: 24),

            // ── Nom du groupe ──
            _buildNameField(l10n),
            const SizedBox(height: 16),

            // ── Description ──
            _buildDescriptionField(l10n),
            const SizedBox(height: 24),

            // ── Code d'invitation ──
            _buildInviteCodeSection(l10n),
            const SizedBox(height: 24),

            // ── Gérer les membres ──
            _buildManageMembersButton(l10n),
            const SizedBox(height: 16),

            // ── Groupe public ──
            _buildPublicToggle(l10n),
            const SizedBox(height: 32),

            // ── Zone de danger ──
            _buildDangerZone(l10n),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarSection(AppLocalizations l10n) {
    return Center(
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Semantics(
                label: l10n.t('group_avatar'),
                child: CircleAvatar(
                  radius: _kAvatarRadius,
                  backgroundColor: ThixPolicy.surfaceSoft,
                  backgroundImage: _groupInfo?.avatarUrl != null
                      ? NetworkImage(_groupInfo!.avatarUrl!)
                      : null,
                  child: _groupInfo?.avatarUrl == null
                      ? Icon(
                          Icons.group_rounded,
                          size: _kAvatarRadius,
                          color: ThixPolicy.primary.withOpacity(0.5),
                        )
                      : null,
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Semantics(
                  button: true,
                  label: l10n.t('group_change_avatar'),
                  child: GestureDetector(
                    onTap: _changeAvatar,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: ThixPolicy.gold,
                        shape: BoxShape.circle,
                        border: Border.all(color: ThixPolicy.card, width: 2),
                      ),
                      child: Icon(
                        Icons.camera_alt_rounded,
                        size: _kCameraIconSize,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Semantics(
            button: true,
            label: l10n.t('group_change_avatar'),
            child: TextButton(
              onPressed: _changeAvatar,
              child: Text(
                l10n.t('group_change_avatar'),
                style: TextStyle(
                  color: ThixPolicy.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNameField(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.t('group_name_label'),
          style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.bold),
        ),
        const SizedBox(height: 8),
        Semantics(
          label: l10n.t('group_name_label'),
          textField: true,
          child: TextField(
            controller: _nameController,
            maxLength: _kMaxGroupNameLength,
            enabled: !_isSaving,
            decoration: InputDecoration(
              counterText: '',
              hintText: l10n.t('group_name_hint'),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: ThixPolicy.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: ThixPolicy.primary, width: 1.5),
              ),
              filled: true,
              fillColor: ThixPolicy.card,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDescriptionField(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.t('group_description_label'),
          style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.bold),
        ),
        const SizedBox(height: 8),
        Semantics(
          label: l10n.t('group_description_label'),
          textField: true,
          child: TextField(
            controller: _descController,
            maxLength: _kMaxDescriptionLength,
            maxLines: 3,
            minLines: 2,
            enabled: !_isSaving,
            decoration: InputDecoration(
              counterText: '',
              hintText: l10n.t('group_description_hint'),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: ThixPolicy.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: ThixPolicy.primary, width: 1.5),
              ),
              filled: true,
              fillColor: ThixPolicy.card,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInviteCodeSection(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.t('group_invite_code_label'),
          style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.bold),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: ThixPolicy.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ThixPolicy.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _inviteCode ?? l10n.t('group_no_invite_code'),
                  style: TextStyle(
                    fontSize: _kCodeFontSize,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: _inviteCode != null ? ThixPolicy.textMain : ThixPolicy.textMuted,
                  ),
                ),
              ),
              Semantics(
                button: true,
                label: l10n.t('group_copy_code'),
                child: IconButton(
                  icon: Icon(Icons.copy_rounded, color: ThixPolicy.primary, size: 20),
                  onPressed: _copyInviteCode,
                  tooltip: l10n.t('group_copy_code'),
                ),
              ),
              Semantics(
                button: true,
                label: l10n.t('group_regenerate_code'),
                child: IconButton(
                  icon: Icon(Icons.refresh_rounded, color: ThixPolicy.gold, size: 20),
                  onPressed: _isSaving ? null : _regenerateInviteCode,
                  tooltip: l10n.t('group_regenerate_code'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildManageMembersButton(AppLocalizations l10n) {
    return Semantics(
      button: true,
      label: l10n.t('group_manage_members'),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _isSaving ? null : _navigateToGroupInfo,
          icon: const Icon(Icons.people_rounded, size: 18),
          label: Text(l10n.t('group_manage_members')),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: ThixPolicy.primary),
            foregroundColor: ThixPolicy.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildPublicToggle(AppLocalizations l10n) {
    return Container(
      decoration: BoxDecoration(
        color: ThixPolicy.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ThixPolicy.border),
      ),
      child: Semantics(
        label: l10n.t('group_public_label'),
        checked: _groupInfo?.isPublic ?? false,
        child: SwitchListTile(
          title: Text(
            l10n.t('group_public_label'),
            style: TextStyle(fontWeight: FontWeight.w600, color: ThixPolicy.textMain),
          ),
          subtitle: Text(
            l10n.t('group_public_subtitle'),
            style: TextStyle(fontSize: 12, color: ThixPolicy.textMuted),
          ),
          value: _groupInfo?.isPublic ?? false,
          onChanged: _isSaving
              ? null
              : (value) {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _groupInfo = _groupInfo?.copyWith(isPublic: value);
                  });
                },
          activeColor: ThixPolicy.gold,
          activeTrackColor: ThixPolicy.gold.withOpacity(0.3),
        ),
      ),
    );
  }

  Widget _buildDangerZone(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ThixPolicy.danger.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ThixPolicy.danger.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.t('group_danger_zone_title'),
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: ThixPolicy.danger,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.t('group_danger_zone_message'),
            style: TextStyle(fontSize: 12, color: ThixPolicy.textMuted),
          ),
          const SizedBox(height: 12),
          Semantics(
            button: true,
            label: l10n.t('group_delete_button'),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isSaving ? null : _showDeleteGroupDialog,
                icon: const Icon(Icons.delete_rounded, size: 18),
                label: Text(l10n.t('group_delete_button')),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: ThixPolicy.danger),
                  foregroundColor: ThixPolicy.danger,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
