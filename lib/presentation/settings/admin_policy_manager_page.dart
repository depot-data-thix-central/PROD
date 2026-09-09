// lib/presentation/settings/admin_policy_manager_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import '../../theme.dart';

class AdminPolicyManagerPage extends StatefulWidget {
  const AdminPolicyManagerPage({super.key});
  @override
  State<AdminPolicyManagerPage> createState() => _AdminPolicyManagerPageState();
}

class _AdminPolicyManagerPageState extends State<AdminPolicyManagerPage> {
  final _sb = Supabase.instance.client;
  List<Map<String, dynamic>> _policies = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rows = await _sb
          .from('app_policies')
          .select('id, slug, title, content, version, updated_at')
          .order('slug');
      if (mounted) setState(() { _policies = List<Map<String, dynamic>>.from(rows); _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _loading = false; });
    }
  }

  Future<void> _edit(Map<String, dynamic> p) async {
    final l10n = AppLocalizations.of(context);
    final titleCtrl = TextEditingController(text: p['title']);
    final contentCtrl = TextEditingController(text: p['content']);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.t('settings_policy_edit')),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: titleCtrl,
                  decoration: InputDecoration(labelText: l10n.t('settings_title'))),
              const SizedBox(height: 12),
              Expanded(
                child: TextField(
                  controller: contentCtrl,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: InputDecoration(
                      labelText: l10n.t('settings_policy_content'),
                      border: const OutlineInputBorder()),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.t('common_cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.t('settings_policy_save'))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _sb.from('app_policies').update({
        'title': titleCtrl.text.trim(),
        'content': contentCtrl.text,
        'version': ((p['version'] as int?) ?? 1) + 1,
        'updated_at': DateTime.now().toIso8601String(),
        'updated_by': _sb.auth.currentUser?.id,
      }).eq('id', p['id']);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.t('settings_policy_saved'))));
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: context.theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(l10n.t('settings_admin_policies')),
        backgroundColor: context.theme.scaffoldBackgroundColor,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: _policies.length,
              itemBuilder: (_, i) {
                final p = _policies[i];
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.description_rounded),
                    title: Text(p['title'] ?? ''),
                    subtitle: Text(
                        '${l10n.t('settings_policy_version')} ${p['version']}'),
                    trailing: const Icon(Icons.edit_rounded),
                    onTap: () => _edit(p),
                  ),
                );
              },
            ),
    );
  }
}
