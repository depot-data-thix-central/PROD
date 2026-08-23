// lib/presentation/thix_ia/widgets/document_card.dart
import 'package:flutter/material.dart';
import '../../../../core/theme/thix_design_policy.dart';
import '../models/document.dart';

class DocumentCard extends StatelessWidget {
  const DocumentCard({super.key, required this.document, this.onTap, this.onDelete});

  final ProjectDocument document;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(ThixPolicy.rMd), border: Border.all(color: ThixPolicy.border), boxShadow: ThixPolicy.shadowCard(opacity: 0.04)),
      child: ListTile(
        onTap: onTap,
        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: _color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
          child: Icon(_icon, color: _color, size: 22),
        ),
        title: Text(document.fileName, style: ThixPolicy.bodyStyle.copyWith(fontWeight: ThixPolicy.semiBold), maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 2),
            Text('${(document.fileSize / 1024).toStringAsFixed(1)} KB • ${document.chunksCount} chunks • ${document.status.name}', style: ThixPolicy.captionStyle),
            SizedBox(height: 6),
            Row(children: [
              _StatusDot(status: document.status),
              SizedBox(width: 6),
              Text(document.isIndexed? 'Indexé RAG' : 'Indexation...', style: ThixPolicy.microStyle.copyWith(color: document.isIndexed? ThixPolicy.success : ThixPolicy.warning)),
            ]),
          ],
        ),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          if (document.isIndexed) Icon(Icons.check_circle_rounded, color: ThixPolicy.success, size: 18) else SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
          if (onDelete!= null)...[SizedBox(width: 8), GestureDetector(onTap: onDelete, child: Icon(Icons.delete_outline_rounded, size: 18, color: ThixPolicy.textMuted))],
        ]),
      ),
    );
  }

  Color get _color {
    if (document.isPdf) return ThixPolicy.danger;
    if (document.isImage) return ThixPolicy.info;
    return ThixPolicy.primary;
  }

  IconData get _icon {
    if (document.isPdf) return Icons.picture_as_pdf_rounded;
    if (document.isImage) return Icons.image_rounded;
    if (document.fileName.endsWith('xlsx') || document.fileName.endsWith('xls')) return Icons.table_chart_rounded;
    return Icons.description_rounded;
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.status});
  final DocumentStatus status;
  @override
  Widget build(BuildContext context) {
    Color c;
    switch (status) {
      case DocumentStatus.uploading: c = ThixPolicy.warning; break;
      case DocumentStatus.processing: c = ThixPolicy.info; break;
      case DocumentStatus.indexed: c = ThixPolicy.success; break;
      case DocumentStatus.failed: c = ThixPolicy.danger; break;
    }
    return Container(width: 6, height: 6, decoration: BoxDecoration(color: c, shape: BoxShape.circle));
  }
}
