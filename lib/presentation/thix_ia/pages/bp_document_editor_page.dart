import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/bp_post_process_service.dart';

class BpDocumentEditorPage extends StatefulWidget {
  const BpDocumentEditorPage({super.key, required this.projectCode});
  final String projectCode;

  @override
  State<BpDocumentEditorPage> createState() => _BpDocumentEditorPageState();
}

class _BpDocumentEditorPageState extends State<BpDocumentEditorPage> {
  final _client = Supabase.instance.client;
  bool _loading = true;
  bool _saving = false;
  String? _docId;
  Map<String, dynamic> _sections = {};
  String? _error;

  final _controllers = <String, TextEditingController>{};

  static const _keys = [
    ('executive_summary', 'Résumé exécutif'),
    ('value_proposition', 'Proposition de valeur'),
    ('market', 'Marché'),
    ('strategy', 'Stratégie'),
    ('team', 'Équipe'),
    ('financials', 'Finances'),
    ('risks', 'Risques'),
    ('roadmap', 'Feuille de route'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final doc = await _client
          .from('thix_bp_documents')
          .select()
          .eq('project_code', widget.projectCode)
          .order('updated_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (doc == null) {
        setState(() {
          _loading = false;
          _error = 'Aucun Business Plan en base. Génère-le d\'abord.';
        });
        return;
      }

      _docId = doc['id']?.toString();
      final raw = doc['sections'];
      if (raw is Map) {
        _sections = Map<String, dynamic>.from(raw);
      }

      for (final e in _keys) {
        _controllers[e.$1] = TextEditingController(
          text: _sections[e.$1]?.toString() ?? '',
        );
      }
    } catch (e) {
      _error = 'Erreur chargement : $e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveAndRecompile() async {
    if (_docId == null || _saving) return;
    setState(() => _saving = true);

    try {
      // 1) Mettre à jour les sections depuis les champs
      final updated = Map<String, dynamic>.from(_sections);
      for (final e in _keys) {
        updated[e.$1] = _controllers[e.$1]?.text.trim() ?? '';
      }

      await _client.from('thix_bp_documents').update({
        'sections': updated,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', _docId!);

      // 2) Recompiler PDF A4
      final bytes = await BpPostProcessService().buildA4Pdf(
        projectCode: widget.projectCode,
        title: updated['title']?.toString() ?? 'Business Plan',
        sections: updated,
      );

      // 3) Re-upload Storage + maj pdf_path
      final path =
          '\( {widget.projectCode}/business_plan_ \){DateTime.now().millisecondsSinceEpoch}.pdf';
      await _client.storage.from('project-documents').uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'application/pdf',
              upsert: true,
            ),
          );

      await _client.from('thix_bp_documents').update({
        'pdf_path': path,
        'pdf_size': bytes.length,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', _docId!);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('BP enregistré + PDF recompilé')),
      );
      setState(() => _sections = updated);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur : $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Éditer le Business Plan'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _saveAndRecompile,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Enregistrer + PDF'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(_error!, textAlign: TextAlign.center),
                ))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    for (final e in _keys) ...[
                      Text(e.$2,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _controllers[e.$1],
                        maxLines: 6,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ],
                ),
    );
  }
}
