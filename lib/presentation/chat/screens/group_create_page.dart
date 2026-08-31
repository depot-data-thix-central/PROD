// lib/presentation/chat/group/group_create_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/models/chat/chat_conversation.dart';
import 'package:thix_id/services/chat/chat_service.dart';
import 'package:thix_id/services/chat/group_service.dart';

// ============================================================================
// CONSTANTS
// ============================================================================
const int _kMaxGroupNameLength = 100;
const int _kMaxDescriptionLength = 500;
const int _kMinGroupNameLength = 3;
const int _kMinMembersRequired = 2;
const double _kAvatarRadius = 12.0;
const double _kAvatarInitialFontSize = 10.0;

// ============================================================================
// VALIDATORS
// ============================================================================
class _GroupCreateValidators {
  _GroupCreateValidators._();

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
    if (msg.contains('already exists')) {
      return l10n.t('group_create_error_name_exists');
    }
    return l10n.t('group_create_error_generic');
  }
}

// ============================================================================
// GROUP CREATE PAGE
// ============================================================================

/// Écran de création de groupe : nom, description, sélection des membres.
///
/// Fonctionnalités :
/// - Saisie nom (obligatoire, 3-100 caractères)
/// - Saisie description (optionnelle, max 500 caractères)
/// - Sélection de membres (min 2)
/// - Recherche dans les contacts
/// - Affichage des membres sélectionnés (chips)
class GroupCreatePage extends StatefulWidget {
  const GroupCreatePage({super.key});

  @override
  State<GroupCreatePage> createState() => _GroupCreatePageState();
}

class _GroupCreatePageState extends State<GroupCreatePage> {
  late GroupService _groupService;
  late ChatService _chatService;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _contacts = [];
  List<String> _selectedUserIds = [];
  bool _isLoading = true;
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _groupService = GroupService(Supabase.instance.client);
    _chatService = ChatService(Supabase.instance.client);
    debugPrint('[GroupCreate] 🚀 Page opened');
    _loadContacts();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _searchController.dispose();
    debugPrint('[GroupCreate] 👋 Page disposed');
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

  // ── LOAD CONTACTS ─────────────────────────────────────────────────────────

  Future<void> _loadContacts() async {
    final l10n = AppLocalizations.of(context);

    setState(() => _isLoading = true);
    debugPrint('[GroupCreate] 🔄 Loading contacts...');

    try {
      final uid = _chatService.currentUserId;
      if (uid == null) {
        debugPrint('[GroupCreate] ❌ No current user ID');
        setState(() => _isLoading = false);
        _showError(l10n.t('group_error_no_user'));
        return;
      }

      final supabase = Supabase.instance.client;
      final data = await supabase
          .from('conversation_participants')
          .select('''
            user_id,
            profiles!user_id (id, username, full_name, avatar_url)
          ''')
          .neq('user_id', uid);

      final Map<String, Map<String, dynamic>> uniqueContacts = {};
      for (var p in data as List) {
        final profile = p['profiles'] as Map<String, dynamic>?;
        if (profile != null) {
          final id = profile['id'] as String;
          if (!uniqueContacts.containsKey(id)) {
            uniqueContacts[id] = {
              'id': id,
              'username': _GroupCreateValidators.sanitize(profile['username']?.toString(), maxLength: 50),
              'full_name': _GroupCreateValidators.sanitize(profile['full_name']?.toString(), maxLength: 100),
              'avatar_url': profile['avatar_url']?.toString(),
            };
          }
        }
      }

      if (!mounted) return;

      setState(() {
        _contacts = uniqueContacts.values.toList();
        _isLoading = false;
      });

      debugPrint('[GroupCreate] ✓ Contacts loaded (${_contacts.length})');
    } catch (e) {
      debugPrint('[GroupCreate] ❌ Load contacts error: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError(l10n.t('group_create_error_load_contacts'));
    }
  }

  // ── FILTER CONTACTS ───────────────────────────────────────────────────────

  List<Map<String, dynamic>> get _filteredContacts {
    final query = _GroupCreateValidators.sanitize(_searchController.text.toLowerCase().trim(), maxLength: 100);
    if (query.isEmpty) return _contacts;
    return _contacts.where((c) {
      final name = (c['full_name'] ?? c['username'] ?? '').toLowerCase();
      return name.contains(query);
    }).toList();
  }

  // ── TOGGLE SELECTION ──────────────────────────────────────────────────────

  void _toggleSelection(String userId) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedUserIds.contains(userId)) {
        _selectedUserIds.remove(userId);
        debugPrint('[GroupCreate] ➖ Removed member: $userId');
      } else {
        _selectedUserIds.add(userId);
        debugPrint('[GroupCreate] ➕ Added member: $userId');
      }
    });
  }

  // ── CREATE GROUP ──────────────────────────────────────────────────────────

  Future<void> _createGroup() async {
    final l10n = AppLocalizations.of(context);

    if (_isCreating) {
      debugPrint('[GroupCreate] ⚠️ Creation already in progress');
      return;
    }

    final name = _GroupCreateValidators.sanitize(_nameController.text.trim(), maxLength: _kMaxGroupNameLength);
    final description = _GroupCreateValidators.sanitize(_descController.text.trim(), maxLength: _kMaxDescriptionLength);

    if (!_GroupCreateValidators.isValidGroupName(name)) {
      _showError(l10n.t('group_create_error_name_invalid'));
      return;
    }

    if (_selectedUserIds.length < _kMinMembersRequired) {
      _showError(l10n.t('group_create_error_min_members', args: ['$_kMinMembersRequired']));
      return;
    }

    setState(() => _isCreating = true);
    HapticFeedback.mediumImpact();
    debugPrint('[GroupCreate] 🚀 Creating group: $name');

    try {
      final conv = await _groupService.createGroup(
        name: name,
        description: description.isNotEmpty ? description : null,
        memberIds: _selectedUserIds,
        isPublic: false,
      );

      if (!mounted) return;
      setState(() => _isCreating = false);
      _showSuccess(l10n.t('group_create_success'));
      debugPrint('[GroupCreate] ✓ Group created: ${conv.id}');
      Navigator.pop(context, conv);
    } catch (e) {
      debugPrint('[GroupCreate] ❌ Create error: $e');
      if (!mounted) return;
      setState(() => _isCreating = false);
      _showError(_GroupCreateValidators.friendlyError(e, l10n));
    }
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      appBar: AppBar(
        backgroundColor: ThixPolicy.primary,
        foregroundColor: Colors.white,
        title: Text(
          l10n.t('group_create_title'),
          style: ThixPolicy.titleStyle.copyWith(
            color: Colors.white,
            fontWeight: ThixPolicy.bold,
          ),
        ),
        leading: Semantics(
          button: true,
          label: l10n.t('close'),
          child: IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white),
            onPressed: () {
              HapticFeedback.selectionClick();
              Navigator.pop(context);
            },
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _isCreating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Semantics(
                    button: true,
                    label: l10n.t('group_create_button'),
                    enabled: _selectedUserIds.length >= _kMinMembersRequired && !_isCreating,
                    child: TextButton(
                      onPressed: (_selectedUserIds.length >= _kMinMembersRequired && !_isCreating) ? _createGroup : null,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        disabledForegroundColor: ThixPolicy.textMuted.withOpacity(0.5),
                      ),
                      child: Text(
                        l10n.t('group_create_button'),
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: ThixPolicy.primary))
          : _buildContent(l10n),
    );
  }

  Widget _buildContent(AppLocalizations l10n) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Nom du groupe ──
          _buildNameField(l10n),
          const SizedBox(height: 12),

          // ── Description ──
          _buildDescriptionField(l10n),
          const SizedBox(height: 20),

          // ── Sélection des membres ──
          _buildMembersSection(l10n),
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
            enabled: !_isCreating,
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
            maxLines: 2,
            minLines: 2,
            enabled: !_isCreating,
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

  Widget _buildMembersSection(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.t('group_add_members'),
          style: ThixPolicy.labelStyle.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: ThixPolicy.textMain,
          ),
        ),
        const SizedBox(height: 8),

        // ── Champ de recherche ──
        Semantics(
          label: l10n.t('group_search_contacts'),
          textField: true,
          child: TextField(
            controller: _searchController,
            enabled: !_isCreating,
            decoration: InputDecoration(
              hintText: l10n.t('group_search_hint'),
              prefixIcon: Icon(Icons.search, color: ThixPolicy.textMuted),
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
        const SizedBox(height: 12),

        // ── Chips des membres sélectionnés ──
        if (_selectedUserIds.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _selectedUserIds.map((id) {
                final contact = _contacts.firstWhere((c) => c['id'] == id);
                final name = contact['full_name'] ?? contact['username'] ?? l10n.t('group_unknown_user');
                final sanitizedName = _GroupCreateValidators.sanitize(name, maxLength: 50);
                return Semantics(
                  button: true,
                  label: '${l10n.t('group_remove_member')}: $sanitizedName',
                  child: Chip(
                    label: Text(sanitizedName),
                    onDeleted: () => _toggleSelection(id),
                    deleteIcon: Icon(Icons.close, size: 16, color: ThixPolicy.textMuted),
                    backgroundColor: ThixPolicy.gold.withOpacity(0.2),
                    avatar: CircleAvatar(
                      radius: _kAvatarRadius,
                      backgroundColor: ThixPolicy.primary,
                      backgroundImage: contact['avatar_url'] != null
                          ? NetworkImage(contact['avatar_url'])
                          : null,
                      child: contact['avatar_url'] == null
                          ? Text(
                              _GroupCreateValidators.safeInitial(name),
                              style: TextStyle(fontSize: _kAvatarInitialFontSize, color: Colors.white),
                            )
                          : null,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
        ],

        // ── Liste des contacts ──
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _filteredContacts.length,
          separatorBuilder: (_, __) => Divider(height: 1, color: ThixPolicy.border),
          itemBuilder: (context, index) {
            final contact = _filteredContacts[index];
            final userId = contact['id'] as String;
            final isSelected = _selectedUserIds.contains(userId);
            final name = contact['full_name'] ?? contact['username'] ?? l10n.t('group_unknown_user');
            final sanitizedName = _GroupCreateValidators.sanitize(name, maxLength: 100);
            final avatar = contact['avatar_url'];

            return Semantics(
              button: true,
              label: sanitizedName,
              selected: isSelected,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: ThixPolicy.surfaceSoft,
                  backgroundImage: avatar != null ? NetworkImage(avatar) : null,
                  child: avatar == null
                      ? Text(
                          _GroupCreateValidators.safeInitial(name),
                          style: TextStyle(color: ThixPolicy.primary, fontWeight: FontWeight.w600),
                        )
                      : null,
                ),
                title: Text(
                  sanitizedName,
                  style: ThixPolicy.bodyStyle.copyWith(fontWeight: FontWeight.w500),
                ),
                trailing: isSelected
                    ? Icon(Icons.check_circle_rounded, color: ThixPolicy.gold, size: 24)
                    : Icon(Icons.circle_outlined, color: ThixPolicy.textMuted, size: 24),
                onTap: _isCreating ? null : () => _toggleSelection(userId),
                enabled: !_isCreating,
              ),
            );
          },
        ),
      ],
    );
  }
}
