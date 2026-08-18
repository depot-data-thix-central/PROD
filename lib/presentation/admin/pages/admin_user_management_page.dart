import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:thix_id/supabase/supabase_config.dart';
import 'package:thix_id/services/admin_user_service.dart';
import 'package:thix_id/theme.dart';

class AdminUserManagementPage extends StatefulWidget {
  const AdminUserManagementPage({super.key});

  @override
  State<AdminUserManagementPage> createState() => _AdminUserManagementPageState();
}

class _AdminUserManagementPageState extends State<AdminUserManagementPage> {
  final _search = TextEditingController();
  final _adminUser = AdminUserService();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _rows = const [];

  @override
  void initState() {
    super.initState();
    _load();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Primary: order by last_update if present.
      List<Map<String, dynamic>> res;
      try {
        res = await SupabaseService.select(
          'thix_public_profiles',
          select:
              'id,user_id,display_name,avatar_url,identity_preview_url,last_update,created_at,account_type,is_suspended,suspended_at,suspended_reason',
          orderBy: 'last_update',
          ascending: false,
          limit: 250,
        );
      } catch (e) {
        debugPrint('AdminUserManagementPage: last_update order failed, fallback err=$e');
        try {
          res = await SupabaseService.select(
            'thix_public_profiles',
            select:
                'id,user_id,display_name,avatar_url,identity_preview_url,last_update,created_at,account_type,is_suspended,suspended_at,suspended_reason',
            orderBy: 'id',
            ascending: false,
            limit: 250,
          );
        } catch (e2) {
          // Schema-safe fallback if columns not deployed yet.
          debugPrint('AdminUserManagementPage: fallback select failed, retry minimal cols err=$e2');
          res = await SupabaseService.select(
            'thix_public_profiles',
            select: 'id,user_id,display_name,avatar_url,identity_preview_url,last_update,created_at,account_type',
            orderBy: 'id',
            ascending: false,
            limit: 250,
          );
        }
      }
      if (!mounted) return;
      setState(() => _rows = res);
    } catch (e) {
      debugPrint('AdminUserManagementPage: fetch failed err=$e');
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _search.text.trim().toLowerCase();
    final filtered = q.isEmpty
        ? _rows
        : _rows.where((r) {
            final display = (r['display_name'] ?? '').toString().toLowerCase();
            final userId = (r['user_id'] ?? '').toString().toLowerCase();
            final id = (r['id'] ?? '').toString().toLowerCase();
            return display.contains(q) || userId.contains(q) || id.contains(q);
          }).toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Header(search: _search, onRefresh: _load, count: filtered.length),
        const SizedBox(height: AppSpacing.md),
         Expanded(
           child: _loading
               ? const Center(child: CircularProgressIndicator(color: Colors.white))
               : (_error != null)
                   ? _ErrorState(error: _error!, onRetry: _load)
                   : _UserList(rows: filtered, onActionDone: _load, adminUser: _adminUser),
         ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  final TextEditingController search;
  final VoidCallback onRefresh;
  final int count;
  const _Header({required this.search, required this.onRefresh, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('User Management', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: AdminCyberColors.text)),
              const SizedBox(height: 4),
              Text('Source: thix_public_profiles • $count résultat(s)', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AdminCyberColors.textDim)),
            ],
          ),
        ),
        SizedBox(
          width: 320,
          child: TextField(
            controller: search,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AdminCyberColors.text),
            decoration: InputDecoration(
              hintText: 'Search users, UID, name…',
              hintStyle: Theme.of(context).textTheme.bodySmall?.copyWith(color: AdminCyberColors.textDim),
              prefixIcon: const Icon(Icons.search_rounded, color: AdminCyberColors.neonCyan),
              filled: true,
              fillColor: AdminCyberColors.panel.withValues(alpha: 0.72),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: AdminCyberColors.stroke.withValues(alpha: 0.9)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AdminCyberColors.electricBlue, width: 1.2),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: AdminCyberColors.stroke.withValues(alpha: 0.9)),
            foregroundColor: AdminCyberColors.text,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh_rounded, color: AdminCyberColors.neonCyan),
          label: const Text('Fetch Data'),
        ),
      ],
    );
  }
}

class _UserList extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  final VoidCallback onActionDone;
  final AdminUserService adminUser;
  const _UserList({required this.rows, required this.onActionDone, required this.adminUser});

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return Center(
        child: Text('Aucun profil.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AdminCyberColors.textDim)),
      );
    }

    return ListView.separated(
      itemCount: rows.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) => _UserTile(row: rows[index], adminUser: adminUser, onActionDone: onActionDone),
    );
  }
}

class _UserTile extends StatelessWidget {
  final Map<String, dynamic> row;
  final AdminUserService adminUser;
  final VoidCallback onActionDone;
  const _UserTile({required this.row, required this.adminUser, required this.onActionDone});

  @override
  Widget build(BuildContext context) {
    final displayName = (row['display_name'] ?? '—').toString().trim();
    final userId = (row['user_id'] ?? '').toString().trim();
    final avatarUrl = (row['avatar_url'] ?? '').toString().trim();
    final lastUpdate = (row['last_update'] ?? '').toString().trim();
    final identityPreview = (row['identity_preview_url'] ?? '').toString().trim();
    final createdAt = (row['created_at'] ?? '').toString().trim();
    final accountType = (row['account_type'] ?? '').toString().trim();
    final isSuspended = (row['is_suspended'] ?? false) == true;
    final suspendedReason = (row['suspended_reason'] ?? '').toString().trim();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        color: AdminCyberColors.panel.withValues(alpha: 0.78),
        border: Border.all(color: AdminCyberColors.stroke.withValues(alpha: 0.9)),
      ),
      child: Row(
        children: [
          _Avatar(url: avatarUrl),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(displayName.isEmpty ? '—' : displayName, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AdminCyberColors.text)),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 10,
                  runSpacing: 6,
                  children: [
                    _MetaChip(icon: Icons.person_rounded, label: userId.isEmpty ? 'user_id: —' : 'user_id: ${_ellipsis(userId, 16)}'),
                    if (accountType.isNotEmpty) _MetaChip(icon: Icons.badge_rounded, label: 'type: ${_ellipsis(accountType, 16)}'),
                    if (createdAt.isNotEmpty) _MetaChip(icon: Icons.calendar_month_rounded, label: 'inscrit: ${_ellipsis(createdAt, 10)}'),
                    if (lastUpdate.isNotEmpty) _MetaChip(icon: Icons.update_rounded, label: 'update: ${_ellipsis(lastUpdate, 20)}'),
                    if (identityPreview.isNotEmpty) _MetaChip(icon: Icons.badge_rounded, label: 'identity: ready'),
                    if (isSuspended) _MetaChip(icon: Icons.block_rounded, label: suspendedReason.isEmpty ? 'suspended' : 'suspended: ${_ellipsis(suspendedReason, 18)}'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (identityPreview.isNotEmpty)
            IconButton(
              tooltip: 'Preview identité',
              onPressed: () => _showIdentityPreview(context, identityPreview),
              icon: const Icon(Icons.open_in_new_rounded, color: AdminCyberColors.neonCyan),
            ),
          PopupMenuButton<String>(
            tooltip: 'Actions',
            color: AdminCyberColors.panel,
            onSelected: (value) async {
              final profileId = (row['id'] ?? '').toString().trim();
              if (value == 'view') {
                await _showUserCard(context);
                return;
              }
              if (profileId.isEmpty) return;
              if (value == 'suspend' || value == 'unsuspend') {
                await _confirmSuspend(context, profileId: profileId, suspend: value == 'suspend');
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'view', child: Text('Voir fiche')),
              PopupMenuItem(value: isSuspended ? 'unsuspend' : 'suspend', child: Text(isSuspended ? 'Réactiver' : 'Suspendre')),
            ],
            child: const Icon(Icons.more_vert_rounded, color: AdminCyberColors.textDim),
          ),
        ],
      ),
    );
  }

  static String _ellipsis(String s, int max) => s.length <= max ? s : '${s.substring(0, max)}…';

  Future<void> _showUserCard(BuildContext context) async {
    final displayName = (row['display_name'] ?? '—').toString().trim();
    final userId = (row['user_id'] ?? '').toString().trim();
    final profileId = (row['id'] ?? '').toString().trim();
    final isSuspended = (row['is_suspended'] ?? false) == true;
    final suspendedReason = (row['suspended_reason'] ?? '').toString().trim();

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(14),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AdminCyberColors.stroke.withValues(alpha: 0.9)),
              color: AdminCyberColors.panel.withValues(alpha: 0.92),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text('Fiche utilisateur', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AdminCyberColors.text, fontWeight: FontWeight.w800))),
                    IconButton(onPressed: () => context.pop(), icon: const Icon(Icons.close_rounded, color: AdminCyberColors.textDim)),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    _MetaChip(icon: Icons.tag_rounded, label: 'profile: ${_ellipsis(profileId, 14)}'),
                    _MetaChip(icon: Icons.person_rounded, label: 'user: ${_ellipsis(userId, 18)}'),
                    if (isSuspended) _MetaChip(icon: Icons.block_rounded, label: suspendedReason.isEmpty ? 'suspended' : 'suspended: ${_ellipsis(suspendedReason, 18)}'),
                  ],
                ),
                const SizedBox(height: 10),
                Text(displayName.isEmpty ? '—' : displayName, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AdminCyberColors.text)),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: AdminCyberColors.stroke.withValues(alpha: 0.9)),
                          foregroundColor: AdminCyberColors.text,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () {
                          final text = 'profile_id: $profileId\nuser_id: $userId\nname: $displayName';
                          Clipboard.setData(ClipboardData(text: text));
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Infos copiées.')));
                        },
                        icon: const Icon(Icons.copy_rounded, color: AdminCyberColors.neonCyan),
                        label: const Text('Copier'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AdminCyberColors.electricBlue,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () => context.pop(),
                        icon: const Icon(Icons.check_rounded, color: Colors.white),
                        label: const Text('OK', style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmSuspend(BuildContext context, {required String profileId, required bool suspend}) async {
    final reasonCtrl = TextEditingController();
    final res = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final theme = Theme.of(context);
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: Container(
              margin: const EdgeInsets.all(14),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AdminCyberColors.stroke.withValues(alpha: 0.9)),
                color: AdminCyberColors.panel.withValues(alpha: 0.92),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(suspend ? 'Suspendre utilisateur' : 'Réactiver utilisateur', style: theme.textTheme.titleLarge?.copyWith(color: AdminCyberColors.text, fontWeight: FontWeight.w800))),
                      IconButton(onPressed: () => context.pop(false), icon: const Icon(Icons.close_rounded, color: AdminCyberColors.textDim))
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    suspend
                        ? 'Cette action peut bloquer la connexion et/ou l’accès aux fonctionnalités selon les règles de l’app.'
                        : 'L’utilisateur pourra à nouveau accéder à l’app.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: AdminCyberColors.textDim, height: 1.4),
                  ),
                  if (suspend) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: reasonCtrl,
                      style: theme.textTheme.bodyMedium?.copyWith(color: AdminCyberColors.text),
                      decoration: InputDecoration(
                        hintText: 'Raison (optionnel)…',
                        hintStyle: theme.textTheme.bodySmall?.copyWith(color: AdminCyberColors.textDim),
                        filled: true,
                        fillColor: AdminCyberColors.black.withValues(alpha: 0.22),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: AdminCyberColors.stroke.withValues(alpha: 0.8)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: AdminCyberColors.electricBlue, width: 1.2),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: AdminCyberColors.stroke.withValues(alpha: 0.9)),
                            foregroundColor: AdminCyberColors.text,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () => context.pop(false),
                          child: const Text('Annuler'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: suspend ? AdminCyberColors.danger : AdminCyberColors.electricBlue,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () => context.pop(true),
                          icon: Icon(suspend ? Icons.block_rounded : Icons.check_rounded, color: Colors.white),
                          label: Text(suspend ? 'Suspendre' : 'Réactiver', style: const TextStyle(color: Colors.white)),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
        );
      },
    );

    if (res != true) return;
    try {
      await adminUser.setSuspended(profileId: profileId, suspended: suspend, reason: reasonCtrl.text.trim());
      onActionDone();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(suspend ? 'Utilisateur suspendu.' : 'Utilisateur réactivé.')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Action impossible: $e')));
      }
    }
  }

  static Future<void> _showIdentityPreview(BuildContext context, String url) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          margin: const EdgeInsets.all(14),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AdminCyberColors.stroke.withValues(alpha: 0.9)),
            color: AdminCyberColors.panel.withValues(alpha: 0.92),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text('Identity preview', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AdminCyberColors.text))),
                    IconButton(onPressed: () => context.pop(), icon: const Icon(Icons.close_rounded, color: AdminCyberColors.textDim)),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AspectRatio(
                  aspectRatio: 16 / 10,
                  child: Image.network(
                    url,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Center(
                      child: Text('Impossible de charger l’image.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AdminCyberColors.textDim)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(url, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AdminCyberColors.textDim)),
            ],
          ),
        );
      },
    );
  }
}

class _Avatar extends StatelessWidget {
  final String url;
  const _Avatar({required this.url});

  @override
  Widget build(BuildContext context) {
    final hasUrl = url.trim().isNotEmpty;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminCyberColors.stroke.withValues(alpha: 0.9)),
        gradient: hasUrl ? null : AdminCyberGradients.glowBlue(),
      ),
      clipBehavior: Clip.antiAlias,
      child: hasUrl
          ? Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(Icons.person_rounded, color: Colors.white),
            )
          : const Icon(Icons.person_rounded, color: Colors.white),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: AdminCyberColors.black.withValues(alpha: 0.22),
        border: Border.all(color: AdminCyberColors.stroke.withValues(alpha: 0.7)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AdminCyberColors.textDim),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AdminCyberColors.textDim)),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AdminCyberColors.stroke.withValues(alpha: 0.9)),
            color: AdminCyberColors.panel.withValues(alpha: 0.78),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Supabase error', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AdminCyberColors.text)),
              const SizedBox(height: 8),
              Text(error, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AdminCyberColors.textDim, height: 1.4)),
              const SizedBox(height: 14),
              Row(
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AdminCyberColors.stroke.withValues(alpha: 0.9)),
                      foregroundColor: AdminCyberColors.text,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded, color: AdminCyberColors.neonCyan),
                    label: const Text('Retry'),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Vérifie aussi les RLS policies (thix_public_profiles) pour SUPER_ADMIN.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AdminCyberColors.textDim),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
