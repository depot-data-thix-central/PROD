import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/bp_provider.dart';

class BpDocumentEditorPage extends ConsumerStatefulWidget {
  const BpDocumentEditorPage({super.key, required this.projectCode});
  final String projectCode;

  @override
  ConsumerState<BpDocumentEditorPage> createState() =>
      _BpDocumentEditorPageState();
}

class _BpDocumentEditorPageState extends ConsumerState<BpDocumentEditorPage> {
  final _controllers = <String, TextEditingController>{};
  bool _initialized = false;

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
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _ensureControllers(Map<String, dynamic> sections) {
    if (_initialized) return;
    for (final e in _keys) {
      _controllers[e.$1] = TextEditingController(
        text: sections[e.$1]?.toString() ?? '',
      );
    }
    _initialized = true;
  }

  Map<String, dynamic> _collect(Map<String, dynamic> base) {
    final out = Map<String, dynamic>.from(base);
    for (final e in _keys) {
      out[e.$1] = _controllers[e.$1]?.text.trim() ?? '';
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(bpDocumentControllerProvider(widget.projectCode));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Éditer le Business Plan'),
        actions: [
          async.when(
            data: (doc) {
              if (doc == null) return const SizedBox.shrink();
              return TextButton(
                onPressed: () async {
                  final sections = _collect(doc.sections);
                  await ref
                      .read(bpDocumentControllerProvider(widget.projectCode)
                          .notifier)
                      .saveAndRecompile(sections);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Enregistré + PDF recompilé')),
                    );
                  }
                },
                child: const Text('Enregistrer + PDF'),
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
        data: (doc) {
          if (doc == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Aucun Business Plan en base.\nGénère-le d\'abord depuis Mémoire.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          _ensureControllers(doc.sections);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (doc.pdfUrl != null)
                ListTile(
                  leading: const Icon(Icons.picture_as_pdf),
                  title: const Text('PDF disponible'),
                  subtitle: Text(doc.pdfUrl!, maxLines: 1),
                ),
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
          );
        },
      ),
    );
  }
}
