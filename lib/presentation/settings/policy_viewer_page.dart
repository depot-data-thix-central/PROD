import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
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
  bool _isAdmin = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await Future.wait([_checkAdmin(), _load()]);
  }

  Future<void> _checkAdmin() async {
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) return;
      final row = await Supabase.instance.client
          .from('admin_roles')
          .select('role')
          .eq('user_id', uid)
          .maybeSingle();
      if (!mounted) return;
      setState(() => _isAdmin = row != null);
    } catch (_) {
      // pas admin
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final row = await Supabase.instance.client
          .from('app_policies')
          .select('title, content, version, updated_at')
          .eq('slug', widget.slug)
          .maybeSingle();
      if (!mounted) return;
      setState(() {
        _policy = row;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _openEditor() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PolicyEditorPage(
          slug: widget.slug,
          initial: _policy,
        ),
      ),
    );
    if (saved == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final title = _policy?['title'] as String? ??
        (widget.slug == 'privacy' ? 'Politique de confidentialité' : 'Conditions d’utilisation');

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        actions: [
          if (_isAdmin)
            IconButton(
              tooltip: 'Modifier (admin)',
              icon: const Icon(Icons.edit_outlined),
              onPressed: _openEditor,
            ),
        ],
      ),
      floatingActionButton: _isAdmin
          ? FloatingActionButton.extended(
              onPressed: _openEditor,
              icon: const Icon(Icons.edit),
              label: const Text('Éditer'),
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null || _policy == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error ?? 'Document introuvable'),
                        const SizedBox(height: 12),
                        FilledButton(onPressed: _load, child: const Text('Réessayer')),
                        if (_isAdmin) ...[
                          const SizedBox(height: 8),
                          OutlinedButton(
                            onPressed: _openEditor,
                            child: const Text('Créer ce document'),
                          ),
                        ],
                      ],
                    ),
                  ),
                )
              : Markdown(
                  data: (_policy!['content'] as String?) ?? '',
                  selectable: true,
                  padding: const EdgeInsets.all(20),
                  styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                    p: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.6),
                    h1: Theme.of(context).textTheme.headlineSmall,
                    h2: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
    );
  }
}

class PolicyEditorPage extends StatefulWidget {
  final String slug;
  final Map<String, dynamic>? initial;
  const PolicyEditorPage({super.key, required this.slug, this.initial});

  @override
  State<PolicyEditorPage> createState() => _PolicyEditorPageState();
}

class _PolicyEditorPageState extends State<PolicyEditorPage> {
  late final TextEditingController _title;
  late final TextEditingController _content;
  late final TextEditingController _version;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.initial?['title'] as String? ?? '');
    _content = TextEditingController(text: widget.initial?['content'] as String? ?? '');
    _version = TextEditingController(
      text: '${widget.initial?['version'] ?? '1.0'}',
    );
  }

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    _version.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await Supabase.instance.client.from('app_policies').upsert({
        'slug': widget.slug,
        'title': _title.text.trim(),
        'content': _content.text,
        'version': _version.text.trim(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        'updated_by': Supabase.instance.client.auth.currentUser?.id,
      }, onConflict: 'slug');
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Éditer ${widget.slug}'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Enregistrer'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _title,
            decoration: const InputDecoration(labelText: 'Titre'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _version,
            decoration: const InputDecoration(labelText: 'Version'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _content,
            minLines: 16,
            maxLines: 40,
            decoration: const InputDecoration(
              labelText: 'Contenu (Markdown)',
              alignLabelWithHint: true,
            ),
          ),
        ],
      ),
    );
  }
}
