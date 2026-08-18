import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:thix_id/services/document_service.dart';
import 'package:thix_id/services/external_link_service.dart';
import 'package:thix_id/theme.dart';

/// Small preview chip used after an upload succeeds.
///
/// - Images are shown as thumbnails.
/// - PDFs are shown with a document icon + file name.
/// - A neon/electric-blue border confirms success.
/// - Tapping opens a bottom sheet to view larger and optionally delete.
class UploadDocumentPreview extends StatefulWidget {
  final String bucketName;
  final String storagePath;
  final String fileName;
  final String? mimeType;
  final Future<void> Function()? onDelete;

  /// Optional label (displayed under the thumbnail).
  final String? label;

  const UploadDocumentPreview({
    super.key,
    required this.bucketName,
    required this.storagePath,
    required this.fileName,
    this.mimeType,
    this.onDelete,
    this.label,
  });

  @override
  State<UploadDocumentPreview> createState() => _UploadDocumentPreviewState();
}

class _UploadDocumentPreviewState extends State<UploadDocumentPreview> {
  final _docs = DocumentService();
  String? _downloadUrl;
  bool _loading = false;

  ({String bucket, String path})? _parseBucketPath(String value) {
    final v = value.trim();
    final idx = v.indexOf(':');
    if (idx <= 0) return null;
    final bucket = v.substring(0, idx).trim();
    final path = v.substring(idx + 1).trim();
    if (bucket.isEmpty || path.isEmpty) return null;
    // Avoid false positives on URLs like https://
    if (bucket.startsWith('http')) return null;
    return (bucket: bucket, path: path);
  }

  bool get _isRawUrl {
    final v = widget.storagePath.toLowerCase().trim();
    return v.startsWith('http://') || v.startsWith('https://');
  }

  bool get _isPdf {
    final name = widget.fileName.toLowerCase();
    final mime = (widget.mimeType ?? '').toLowerCase();
    return name.endsWith('.pdf') || mime.contains('pdf');
  }

  @override
  void initState() {
    super.initState();
    _resolveUrl();
  }

  @override
  void didUpdateWidget(covariant UploadDocumentPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.storagePath != widget.storagePath || oldWidget.bucketName != widget.bucketName) {
      _resolveUrl();
    }
  }

  Future<void> _resolveUrl() async {
    setState(() => _loading = true);
    try {
      if (_isRawUrl) {
        if (!mounted) return;
        setState(() => _downloadUrl = widget.storagePath.trim());
        return;
      }

      // Backward/compat: some stored values are in the form "bucket:path".
      final parsed = _parseBucketPath(widget.storagePath);
      final bucket = parsed?.bucket ?? widget.bucketName;
      final path = parsed?.path ?? widget.storagePath;

      final url = await _docs.createDownloadUrl(storagePath: path, bucketName: bucket);
      if (!mounted) return;
      setState(() => _downloadUrl = url);
    } catch (e) {
      debugPrint('UploadDocumentPreview: resolveUrl failed bucket=${widget.bucketName} path=${widget.storagePath} err=$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  static String _downloadUrlWithDisposition(String url, {required String fileName}) {
    final uri = Uri.tryParse(url);
    if (uri == null) return url;
    final qp = Map<String, String>.from(uri.queryParameters);
    // Supabase Storage supports `download` to force attachment disposition.
    qp['download'] = fileName.trim().isEmpty ? '1' : fileName.trim();
    return uri.replace(queryParameters: qp).toString();
  }

  Future<void> _openActionsSheet() async {
    final url = _downloadUrl;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PreviewActionsSheet(
        title: widget.label?.trim().isEmpty ?? true ? widget.fileName : widget.label!.trim(),
        fileName: widget.fileName,
        isPdf: _isPdf,
        downloadUrl: url,
        downloadUrlForAttachment: url == null ? null : _downloadUrlWithDisposition(url, fileName: widget.fileName),
        onDelete: widget.onDelete,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final border = AdminCyberColors.electricBlue;
    final label = (widget.label ?? '').trim();

    return InkWell(
      onTap: _openActionsSheet,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        width: 96,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: border, width: 1.5),
          boxShadow: [
            BoxShadow(color: border.withValues(alpha: 0.22), blurRadius: 14, spreadRadius: 0, offset: const Offset(0, 6)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: SizedBox(
                width: 72,
                height: 54,
                child: _loading
                    ? Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.5, color: border.withValues(alpha: 0.9))))
                    : _isPdf
                        ? _PdfThumb(fileName: widget.fileName)
                        : _downloadUrl == null
                            ? Container(color: Theme.of(context).dividerColor.withValues(alpha: 0.2), child: const Icon(Icons.image_not_supported_rounded, color: LightModeColors.hint))
                            : Image.network(
                                _downloadUrl!,
                                fit: BoxFit.cover,
                                filterQuality: FilterQuality.low,
                                cacheWidth: kIsWeb ? null : 256,
                                errorBuilder: (_, __, ___) => Container(color: Theme.of(context).dividerColor.withValues(alpha: 0.2), child: const Icon(Icons.broken_image_rounded, color: LightModeColors.hint)),
                              ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label.isEmpty ? widget.fileName : label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: context.textStyles.labelSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

class _PdfThumb extends StatelessWidget {
  final String fileName;
  const _PdfThumb({required this.fileName});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.picture_as_pdf_rounded, color: LightModeColors.error, size: 26),
          const SizedBox(height: 4),
          Text(
            fileName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.textStyles.labelSmall?.copyWith(fontWeight: FontWeight.w800, color: LightModeColors.secondaryText),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _PreviewActionsSheet extends StatelessWidget {
  final String title;
  final String fileName;
  final bool isPdf;
  final String? downloadUrl;
  final String? downloadUrlForAttachment;
  final Future<void> Function()? onDelete;

  const _PreviewActionsSheet({
    required this.title,
    required this.fileName,
    required this.isPdf,
    required this.downloadUrl,
    required this.downloadUrlForAttachment,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    final border = AdminCyberColors.electricBlue;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(AppRadius.xl), topRight: Radius.circular(AppRadius.xl)),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text(title, style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.w900))),
                IconButton(onPressed: () => context.pop(), icon: const Icon(Icons.close_rounded)),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (isPdf)
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: border.withValues(alpha: 0.7)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.picture_as_pdf_rounded, color: LightModeColors.error),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(child: Text(fileName, style: context.textStyles.bodyMedium?.copyWith(fontWeight: FontWeight.w800))),
                  ],
                ),
              )
            else
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                child: Container(
                  height: 360,
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: downloadUrl == null
                      ? Center(child: Text('Prévisualisation indisponible.', style: context.textStyles.bodySmall?.copyWith(color: LightModeColors.secondaryText)))
                      : InteractiveViewer(
                          minScale: 1,
                          maxScale: 4,
                          child: Image.network(downloadUrl!, fit: BoxFit.contain),
                        ),
                ),
              ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: OutlinedButton.icon(
                      onPressed: downloadUrl == null ? null : () => ExternalLinkService.open(downloadUrl!),
                      icon: const Icon(Icons.open_in_new_rounded),
                      label: const Text('Ouvrir'),
                      style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.full))),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: downloadUrlForAttachment == null ? null : () => ExternalLinkService.open(downloadUrlForAttachment!),
                      icon: Icon(Icons.download_rounded, color: Theme.of(context).colorScheme.onPrimary),
                      label: Text('Télécharger', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontWeight: FontWeight.w900)),
                      style: ElevatedButton.styleFrom(backgroundColor: LightModeColors.accent, foregroundColor: Theme.of(context).colorScheme.onPrimary, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.full))),
                    ),
                  ),
                ),
                if (onDelete != null) ...[
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('Supprimer ?'),
                              content: const Text('Cette pièce sera supprimée définitivement.'),
                              actions: [
                                TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Annuler')),
                                TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Supprimer')),
                              ],
                            ),
                          );
                          if (ok != true) return;
                          await onDelete!.call();
                          if (context.mounted) context.pop();
                        },
                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                        label: const Text('Supprimer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                        style: ElevatedButton.styleFrom(backgroundColor: LightModeColors.error, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.full))),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
