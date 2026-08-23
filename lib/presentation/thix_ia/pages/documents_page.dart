// lib/presentation/thix_ia/pages/documents_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../core/theme/thix_design_policy.dart';
import '../providers/document_provider.dart';
import '../widgets/empty_state_widget.dart';

class DocumentsPage extends ConsumerStatefulWidget {
  const DocumentsPage({super.key, required this.projectCode});
  final String projectCode;
  @override
  ConsumerState<DocumentsPage> createState() => _DocumentsPageState();
}

class _DocumentsPageState extends ConsumerState<DocumentsPage> {
  bool _uploading = false;

  Future<void> _pickAndUpload() async {
    final result = await FilePicker.platform.pickFiles(withData: true, type: FileType.custom, allowedExtensions: ['pdf', 'docx', 'xlsx', 'png', 'jpg']);
    if (result == null || result.files.first.bytes == null) return;

    final file = result.files.first;
    setState(() => _uploading = true);
    try {
      await ref.read(documentsProvider.notifier).upload(fileName: file.name, bytes: file.bytes!, mimeType: file.extension?? 'application/pdf');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${file.name} uploadé et indexation en cours')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur upload: $e')));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final docsAsync = ref.watch(documentsProvider);

    return Scaffold(
      backgroundColor: ThixPolicy.surface,
      appBar: AppBar(backgroundColor: Colors.white, title: Text('Documents', style: ThixPolicy.h3Style)),
      body: docsAsync.when(
        loading: () => Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur $e')),
        data: (docs) {
          if (docs.isEmpty) {
            return EmptyStateWidget(icon: Icons.folder_open_rounded, title: 'Aucun document', subtitle: 'Importez PDF, DOCX, XLSX. Indexation RAG automatique pour THIX IA.', actionLabel: 'Importer un document', onAction: _pickAndUpload);
          }
          return RefreshIndicator(
            onRefresh: () => ref.read(documentsProvider.notifier).refresh(),
            child: ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: docs.length,
              itemBuilder: (_, i) {
                final d = docs[i];
                return Container(
                  margin: EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(ThixPolicy.rMd), border: Border.all(color: ThixPolicy.border)),
                  child: ListTile(
                    leading: Container(width: 40, height: 40, decoration: BoxDecoration(color: ThixPolicy.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Icon(d.isPdf? Icons.picture_as_pdf_rounded : Icons.description_rounded, color: ThixPolicy.primary)),
                    title: Text(d.fileName, style: ThixPolicy.bodyStyle.copyWith(fontWeight: ThixPolicy.semiBold), maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text('${(d.fileSize / 1024).toStringAsFixed(1)} KB • ${d.status.name} • ${d.chunksCount} chunks', style: ThixPolicy.captionStyle),
                    trailing: d.isIndexed? Icon(Icons.check_circle_rounded, color: ThixPolicy.success, size: 20) : SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(onPressed: _uploading? null : _pickAndUpload, backgroundColor: ThixPolicy.primary, child: _uploading? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Icon(Icons.upload_file_rounded, color: Colors.white)),
    );
  }
}
