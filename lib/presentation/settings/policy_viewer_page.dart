// lib/presentation/settings/policy_viewer_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import '../../theme.dart';

class PolicyViewerPage extends StatefulWidget {
  final String slug; // 'terms' | 'privacy'
  const PolicyViewerPage({super.key, required this.slug});
  @override
  State<PolicyViewerPage> createState() => _PolicyViewerPageState();
}

class _PolicyViewerPageState extends State<PolicyViewerPage> {
  Map<String, dynamic>? _policy;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final row = await Supabase.instance.client
          .from('app_policies')
          .select('title, content, version, updated_at')
          .eq('slug', widget.slug)
          .maybeSingle();
      if (!mounted) return;
      setState(() { _policy = row; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = '$e'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,

      appBar: AppBar(
        title: Text(_policy?['title'] ?? l10n.t('settings_policies_title')),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      ), // <-- CORRECTION 1 : Parenthèse fermante et virgule ajoutées ici

      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null || _policy == null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(l10n.t('settings_policy_not_found')),
                      const SizedBox(height: 12),
                      FilledButton(onPressed: _load,
                          child: Text(l10n.t('common_retry'))),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${l10n.t('settings_policy_version')} ${_policy!['version']} · '
                        '${l10n.t('settings_policy_updated')} ${(_policy!['updated_at'] ?? '').toString().split('T').first}',
                        style: context.textStyles.labelSmall
                            ?.copyWith(color: LightModeColors.hint),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        _policy!['content'] as String,
                        style: context.textStyles.bodyMedium
                            ?.copyWith(height: 1.6),
                      ),
                    ],
                  ),
                ),
    ); 
  }
}
