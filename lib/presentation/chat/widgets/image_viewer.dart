// lib/presentation/chat/widgets/image_viewer.dart
import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:share_plus/share_plus.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/services/chat/media_saver.dart';

// ============================================================================
// CONSTANTS
// ============================================================================
const Duration _kDownloadTimeout = Duration(seconds: 60);
const Duration _kRetryDelay = Duration(milliseconds: 400);
const int _kMaxRetries = 1;
const int _kMaxFileNameLength = 100;
const double _kMinZoomScale = 0.8;
const double _kMaxZoomScale = 6.0;

// ============================================================================
// VALIDATORS
// ============================================================================
class _ViewerValidators {
  _ViewerValidators._();

  static String sanitize(String? input, {int maxLength = 500}) {
    if (input == null || input.trim().isEmpty) return '';
    final doc = html_parser.parse(input);
    var s = doc.body?.text ?? input;
    s = s
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'javascript:', caseSensitive: false), '')
        .replaceAll(RegExp(r'on\w+\s*=', caseSensitive: false), '')
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        .trim();
    return s.length > maxLength ? s.substring(0, maxLength) : s;
  }

  static String? sanitizeUrl(String? url) {
    if (url == null || url.trim().isEmpty) return null;
    final t = url.trim();
    if (!t.startsWith('http://') && !t.startsWith('https://')) return null;
    return t.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
  }

  static String friendlyError(dynamic e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('timeout')) return 'Délai dépassé. Vérifiez votre connexion.';
    if (msg.contains('network') || msg.contains('socket')) return 'Erreur réseau. Réessayez.';
    if (msg.contains('permission') || msg.contains('policy')) return 'Accès non autorisé.';
    if (msg.contains('not found')) return 'Ressource introuvable.';
    if (msg.contains('no space') || msg.contains('storage')) return 'Espace de stockage insuffisant.';
    return 'Une erreur est survenue. Réessayez.';
  }

  /// Extrait le nom de fichier de l'URL de manière sûre
  static String extractFileName(String url, String fallback) {
    try {
      final uri = Uri.tryParse(url);
      if (uri == null) return fallback;
      final segments = uri.pathSegments;
      if (segments.isEmpty) return fallback;
      final last = segments.last;
      if (last.isEmpty) return fallback;
      return sanitize(last, maxLength: _kMaxFileNameLength);
    } catch (_) {
      return fallback;
    }
  }
}

// ============================================================================
// HELPERS
// ============================================================================
Future<T> _viewerRetry<T>(
  Future<T> Function() fn, {
  required String label,
  int maxRetries = _kMaxRetries,
  Duration timeout = _kDownloadTimeout,
}) async {
  int attempt = 0;
  while (true) {
    try {
      return await fn().timeout(timeout);
    } on TimeoutException {
      attempt++;
      if (attempt > maxRetries) {
        debugPrint('[ImageViewer] ❌ $label: timeout after $attempt attempts');
        throw TimeoutException('$label: délai dépassé');
      }
      debugPrint('[ImageViewer] ⏱️ $label timeout — retry $attempt/$maxRetries');
      await Future.delayed(_kRetryDelay);
    } catch (e) {
      debugPrint('[ImageViewer] ❌ $label error: $e');
      rethrow;
    }
  }
}

// ============================================================================
// PUBLIC API
// ============================================================================

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
  final sanitizedUrl = _ViewerValidators.sanitizeUrl(url);
  if (sanitizedUrl == null) {
    debugPrint('[ImageViewer] ⚠️ Invalid URL provided: $url');
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.t('viewer_invalid_url')),
        backgroundColor: ThixPolicy.danger,
        behavior: SnackBarBehavior.floating,
      ),
    );
    return;
  }

  debugPrint('[ImageViewer] 🖼️ Opening viewer for URL: ${sanitizedUrl.substring(0, sanitizedUrl.length > 50 ? 50 : sanitizedUrl.length)}...');

  Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black87,
      pageBuilder: (_, __, ___) => _ImageViewerPage(
        url: sanitizedUrl,
        heroTag: heroTag,
        fileName: fileName,
      ),
    ),
  );
}

// ============================================================================
// IMAGE VIEWER PAGE
// ============================================================================
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
  bool _sharing = false;

  String get _fileName {
    if (widget.fileName != null && widget.fileName!.isNotEmpty) {
      return _ViewerValidators.sanitize(widget.fileName!, maxLength: _kMaxFileNameLength);
    }
    final fallback = 'thix_${DateTime.now().millisecondsSinceEpoch}.jpg';
    return _ViewerValidators.extractFileName(widget.url, fallback);
  }

  Future<void> _download() async {
    if (_downloading) {
      debugPrint('[ImageViewer] ⚠️ Download already in progress');
      return;
    }

    final l10n = AppLocalizations.of(context);
    HapticFeedback.mediumImpact();
    setState(() => _downloading = true);
    debugPrint('[ImageViewer] ⬇️ Starting download: $_fileName');

    final messenger = ScaffoldMessenger.of(context);

    try {
      final path = await _viewerRetry(
        () => MediaSaver.download(url: widget.url, fileName: _fileName),
        label: 'downloadImage',
      );

      if (!mounted) return;
      setState(() => _downloading = false);

      if (path != null) {
        HapticFeedback.lightImpact();
        messenger.showSnackBar(
          SnackBar(
            content: Row(children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text('${l10n.t('viewer_downloaded')}: $path')),
            ]),
            backgroundColor: ThixPolicy.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        debugPrint('[ImageViewer] ✓ Downloaded to: $path');
      } else {
        HapticFeedback.lightImpact();
        messenger.showSnackBar(
          SnackBar(
            content: Row(children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(l10n.t('viewer_download_failed'))),
            ]),
            backgroundColor: ThixPolicy.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
        debugPrint('[ImageViewer] ❌ Download returned null path');
      }
    } catch (e) {
      debugPrint('[ImageViewer] ❌ Download error: $e');
      if (mounted) {
        setState(() => _downloading = false);
        HapticFeedback.lightImpact();
        messenger.showSnackBar(
          SnackBar(
            content: Row(children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(_ViewerValidators.friendlyError(e))),
            ]),
            backgroundColor: ThixPolicy.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _share() async {
    if (_sharing) {
      debugPrint('[ImageViewer] ⚠️ Share already in progress');
      return;
    }

    final l10n = AppLocalizations.of(context);
    HapticFeedback.mediumImpact();
    setState(() => _sharing = true);
    debugPrint('[ImageViewer] 📤 Sharing image');

    try {
      if (kIsWeb) {
        await _viewerRetry(
          () => Share.share(widget.url),
          label: 'shareWeb',
        );
      } else {
        final path = await _viewerRetry(
          () => MediaSaver.download(url: widget.url, fileName: _fileName),
          label: 'downloadForShare',
        );
        if (path != null) {
          await _viewerRetry(
            () => Share.shareXFiles([XFile(path)]),
            label: 'shareFile',
          );
        } else {
          await _viewerRetry(
            () => Share.share(widget.url),
            label: 'shareUrlFallback',
          );
        }
      }
      debugPrint('[ImageViewer] ✓ Share completed');
    } catch (e) {
      debugPrint('[ImageViewer] ❌ Share error: $e');
      if (mounted) {
        HapticFeedback.lightImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(_ViewerValidators.friendlyError(e))),
            ]),
            backgroundColor: ThixPolicy.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final safeFileName = _ViewerValidators.sanitize(_fileName, maxLength: _kMaxFileNameLength);

    final image = CachedNetworkImage(
      imageUrl: widget.url,
      fit: BoxFit.contain,
      placeholder: (_, __) => const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
      errorWidget: (_, __, ___) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.broken_image_outlined, color: Colors.white54, size: 64),
            const SizedBox(height: 16),
            Text(
              l10n.t('viewer_load_error'),
              style: const TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ],
        ),
      ),
    );

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black54,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: Semantics(
          button: true,
          label: l10n.t('common_close'),
          child: IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white),
            onPressed: () {
              HapticFeedback.selectionClick();
              Navigator.pop(context);
            },
          ),
        ),
        title: Text(
          safeFileName.isEmpty ? l10n.t('viewer_image') : safeFileName,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          Semantics(
            button: true,
            label: l10n.t('viewer_share'),
            enabled: !_sharing,
            child: IconButton(
              icon: _sharing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.share_rounded, color: Colors.white),
              onPressed: _sharing ? null : _share,
              tooltip: l10n.t('viewer_share'),
            ),
          ),
          Semantics(
            button: true,
            label: l10n.t('viewer_download'),
            enabled: !_downloading,
            child: IconButton(
              icon: _downloading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.download_rounded, color: Colors.white),
              onPressed: _downloading ? null : _download,
              tooltip: l10n.t('viewer_download'),
            ),
          ),
        ],
      ),
      body: RepaintBoundary(
        child: InteractiveViewer(
          minScale: _kMinZoomScale,
          maxScale: _kMaxZoomScale,
          child: Center(
            child: widget.heroTag != null
                ? Hero(tag: widget.heroTag!, child: image)
                : image,
          ),
        ),
      ),
    );
  }
}
