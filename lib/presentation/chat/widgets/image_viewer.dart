// lib/presentation/chat/widgets/image_viewer.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:thix_id/services/chat/media_saver.dart';

/// Affiche un visualiseur d'image plein écran avec zoom, téléchargement et partage.
///
/// À utiliser depuis n'importe quel widget :
/// ```dart
/// showFullscreenImageViewer(context, url: '...', heroTag: 'img_123');
/// ```
void showFullscreenImageViewer(
  BuildContext context, {
  required String url,
  String? heroTag,
  String? fileName,
}) {
  Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black87,
      pageBuilder: (_, __, ___) => _ImageViewerPage(
        url: url,
        heroTag: heroTag,
        fileName: fileName,
      ),
    ),
  );
}

class _ImageViewerPage extends StatefulWidget {
  final String url;
  final String? heroTag;
  final String? fileName;

  const _ImageViewerPage({
    required this.url,
    this.heroTag,
    this.fileName,
  });

  @override
  State<_ImageViewerPage> createState() => _ImageViewerPageState();
}

class _ImageViewerPageState extends State<_ImageViewerPage> {
  bool _downloading = false;

  String get _fileName {
    if (widget.fileName != null && widget.fileName!.isNotEmpty) return widget.fileName!;
    final uri = Uri.tryParse(widget.url);
    final last = uri?.pathSegments.isNotEmpty == true ? uri!.pathSegments.last : '';
    return last.isEmpty
        ? 'thix_${DateTime.now().millisecondsSinceEpoch}.jpg'
        : last;
  }

  Future<void> _download() async {
    if (_downloading) return;
    setState(() => _downloading = true);

    final messenger = ScaffoldMessenger.of(context);
    final path = await MediaSaver.download(url: widget.url, fileName: _fileName);

    if (!mounted) return;
    setState(() => _downloading = false);

    if (path != null) {
      messenger.showSnackBar(SnackBar(
        content: Text('✅ Téléchargé : $path'),
        backgroundColor: Colors.green,
      ));
    } else {
      messenger.showSnackBar(const SnackBar(
        content: Text('❌ Échec du téléchargement'),
        backgroundColor: Colors.red,
      ));
    }
  }

  Future<void> _share() async {
    try {
      if (kIsWeb) {
        await Share.share(widget.url);
      } else {
        final path = await MediaSaver.download(url: widget.url, fileName: _fileName);
        if (path != null) {
          await Share.shareXFiles([XFile(path)]);
        } else {
          await Share.share(widget.url);
        }
      }
    } catch (e) {
      debugPrint('share image: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final image = Image.network(
      widget.url,
      fit: BoxFit.contain,
      loadingBuilder: (_, child, progress) {
        if (progress == null) return child;
        return const Center(child: CircularProgressIndicator(color: Colors.white));
      },
      errorBuilder: (_, __, ___) => const Center(
        child: Icon(Icons.broken_image_outlined, color: Colors.white54, size: 64),
      ),
    );

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black54,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          _fileName,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded, color: Colors.white),
            onPressed: _share,
            tooltip: 'Partager',
          ),
          IconButton(
            icon: _downloading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.download_rounded, color: Colors.white),
            onPressed: _download,
            tooltip: 'Télécharger',
          ),
        ],
      ),
      body: InteractiveViewer(
        minScale: 0.8,
        maxScale: 6.0,
        child: Center(
          child: widget.heroTag != null
              ? Hero(tag: widget.heroTag!, child: image)
              : image,
        ),
      ),
    );
  }
}
