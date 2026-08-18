import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:thix_id/services/admin_verification_service.dart';
import 'package:thix_id/services/verification_status.dart';
import 'package:thix_id/presentation/common/upload_document_preview.dart';
import 'package:thix_id/theme.dart';

class AdminVerificationPage extends StatefulWidget {
  const AdminVerificationPage({super.key});

  @override
  State<AdminVerificationPage> createState() => _AdminVerificationPageState();
}

class _AdminVerificationPageState extends State<AdminVerificationPage> {
  final _svc = AdminVerificationService();
  bool _loading = true;
  String? _error;
  List<VerificationQueueItem> _items = const [];

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
      final list = await _svc.fetchQueue();
      if (!mounted) return;
      setState(() => _items = list);
    } catch (e) {
      debugPrint('AdminVerificationPage: load failed err=$e');
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _setStatus(VerificationQueueItem item, VerificationStatus status) async {
    try {
      if (status == VerificationStatus.rejected && item.table == AdminVerificationService.identityTable) {
        final reason = await showModalBottomSheet<String>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => _RejectReasonSheet(title: item.title),
        );
        if (reason == null) return;
        await _svc.setStatus(item: item, status: status);
        // best-effort: store reason if column exists.
        try {
          final id = item.linkedRowId;
          if (id != null) {
            await _svc.client
                .from(AdminVerificationService.identityTable)
                .update({'rejection_reason': reason.trim(), 'updated_at': DateTime.now().toUtc().toIso8601String()})
                .eq('id', id);
          }
        } catch (e) {
          debugPrint('AdminVerificationPage: write rejection_reason failed err=$e');
        }
      } else {
        await _svc.setStatus(item: item, status: status);
      }
      if (!mounted) return;
      setState(() => _items = _items.where((i) => i != item).toList(growable: false));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(status == VerificationStatus.verified ? 'Vérifié.' : 'Rejeté.')));
    } catch (e) {
      debugPrint('AdminVerificationPage: setStatus failed err=$e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Action impossible: ${e.toString()}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Vérification', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900, color: Colors.white)),
                    const SizedBox(height: 6),
                    Text('Queue “En attente” (formations • cursus • expériences • identité nationale).', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70, height: 1.4)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                label: const Text('Rafraîchir', style: TextStyle(color: Colors.white)),
                style: OutlinedButton.styleFrom(side: BorderSide(color: Colors.white.withValues(alpha: 0.18)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.full))),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator(color: Colors.white)))
          else if (_error != null)
            Expanded(child: Center(child: Text(_error!, style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70))))
          else if (_items.isEmpty)
            Expanded(child: Center(child: Text('Aucun élément en attente.', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70))))
          else
            Expanded(
              child: ListView.separated(
                itemCount: _items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) => _QueueCard(
                  item: _items[i],
                  onVerify: () => _setStatus(_items[i], VerificationStatus.verified),
                  onReject: () => _setStatus(_items[i], VerificationStatus.rejected),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _QueueCard extends StatelessWidget {
  final VerificationQueueItem item;
  final VoidCallback onVerify;
  final VoidCallback onReject;
  const _QueueCard({required this.item, required this.onVerify, required this.onReject});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isIdentity = item.table == AdminVerificationService.identityTable;
    final bd = Colors.white.withValues(alpha: 0.12);
    final bg = Colors.white.withValues(alpha: 0.06);
    String short(String v) => v.trim().isEmpty ? '—' : (v.length > 52 ? '${v.substring(0, 52)}…' : v);

    final subtitle = isIdentity ? 'Identité nationale • user=${item.userId}' : '${item.table} • id=${item.linkedRowId} • user=${item.userId}';
    final details = <String>[];
    if (isIdentity) {
      final num = (item.payload['national_id_number'] ?? '').toString();
      final docType = (item.payload['document_type'] ?? '').toString();
      if (docType.trim().isNotEmpty) details.add('Type: $docType');
      if (num.trim().isNotEmpty) details.add('Numéro: $num');
    } else {
      final inst = (item.payload['institution'] ?? '').toString();
      final degree = (item.payload['degree'] ?? '').toString();
      if (inst.trim().isNotEmpty) details.add('Institution: $inst');
      if (degree.trim().isNotEmpty) details.add('Diplôme: $degree');
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(18), border: Border.all(color: bd)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(short(item.title), style: theme.textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(999), border: Border.all(color: Colors.orange.withValues(alpha: 0.3))),
                child: Text('En attente', style: theme.textTheme.labelSmall?.copyWith(color: Colors.orange.shade100, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          if (details.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: details.map((d) => _Chip(label: d)).toList(growable: false),
            ),
          ],

          if (isIdentity) ...[
            const SizedBox(height: 12),
            _IdentityDocsRow(payload: item.payload),
          ] else ...[
            const SizedBox(height: 12),
            _EducationDocRow(payload: item.payload),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onVerify,
                  icon: const Icon(Icons.verified_rounded, color: Colors.white),
                  label: const Text('Vérifier', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onReject,
                  icon: const Icon(Icons.block_rounded, color: Colors.white),
                  label: const Text('Rejeter', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                  style: OutlinedButton.styleFrom(side: BorderSide(color: Colors.white.withValues(alpha: 0.18)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _IdentityDocsRow extends StatelessWidget {
  static const _bucketFallback = 'thix-documents';
  final Map<String, dynamic> payload;
  const _IdentityDocsRow({required this.payload});

  @override
  Widget build(BuildContext context) {
    final front = (payload['front_path'] ?? payload['id_document_front_path'] ?? payload['front_storage_path'] ?? '').toString().trim();
    final back = (payload['back_path'] ?? payload['id_document_back_path'] ?? payload['back_storage_path'] ?? '').toString().trim();
    final selfie = (payload['selfie_path'] ?? payload['id_document_selfie_path'] ?? payload['selfie_storage_path'] ?? '').toString().trim();
    final docs = <({String label, String path})>[];
    if (front.isNotEmpty) docs.add((label: 'Recto', path: front));
    if (back.isNotEmpty) docs.add((label: 'Verso', path: back));
    if (selfie.isNotEmpty) docs.add((label: 'Selfie', path: selfie));
    if (docs.isEmpty) {
      return Text('Aucun document joint.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70));
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: docs
          .map(
            (d) => UploadDocumentPreview(
              bucketName: _bucketFallback,
              storagePath: d.path,
              fileName: d.path.split('/').last,
              label: d.label,
            ),
          )
          .toList(growable: false),
    );
  }
}

class _EducationDocRow extends StatelessWidget {
  static const _bucketFallback = 'thix-documents';
  final Map<String, dynamic> payload;
  const _EducationDocRow({required this.payload});

  @override
  Widget build(BuildContext context) {
    final path = (payload['certificate_path'] ?? payload['document_path'] ?? '').toString().trim();
    if (path.isEmpty) {
      return Text('Aucun certificat joint.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70));
    }
    final name = (payload['certificate_file_name'] ?? '').toString().trim();
    return UploadDocumentPreview(
      bucketName: _bucketFallback,
      storagePath: path,
      fileName: name.isEmpty ? path.split('/').last : name,
      label: 'Certificat / Diplôme',
    );
  }
}

class _RejectReasonSheet extends StatefulWidget {
  final String title;
  const _RejectReasonSheet({required this.title});

  @override
  State<_RejectReasonSheet> createState() => _RejectReasonSheetState();
}

class _RejectReasonSheetState extends State<_RejectReasonSheet> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(14),
        padding: EdgeInsets.only(left: 14, right: 14, top: 14, bottom: 14 + MediaQuery.viewInsetsOf(context).bottom),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AdminCyberColors.stroke.withValues(alpha: 0.9)),
          color: AdminCyberColors.panel.withValues(alpha: 0.92),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text('Justifier le refus', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AdminCyberColors.text, fontWeight: FontWeight.w900))),
                IconButton(onPressed: () => context.pop(null), icon: const Icon(Icons.close_rounded, color: AdminCyberColors.textDim)),
              ],
            ),
            Text(widget.title, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AdminCyberColors.textDim)),
            const SizedBox(height: 10),
            TextField(
              controller: _c,
              maxLines: 4,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AdminCyberColors.text),
              decoration: InputDecoration(
                hintText: 'Ex: document illisible, manque verso, informations incohérentes…',
                hintStyle: Theme.of(context).textTheme.bodySmall?.copyWith(color: AdminCyberColors.textDim),
                filled: true,
                fillColor: AdminCyberColors.panelHi.withValues(alpha: 0.72),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: AdminCyberColors.stroke.withValues(alpha: 0.9))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AdminCyberColors.electricBlue, width: 1.2)),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: AdminCyberColors.danger, elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              onPressed: () {
                final t = _c.text.trim();
                if (t.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Motif requis.')));
                  return;
                }
                context.pop(t);
              },
              icon: const Icon(Icons.block_rounded, color: Colors.white),
              label: const Text('Rejeter', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  const _Chip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(999), border: Border.all(color: Colors.white.withValues(alpha: 0.12))),
      child: Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white70, fontWeight: FontWeight.w700)),
    );
  }
}
