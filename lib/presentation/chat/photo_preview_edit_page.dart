// lib/presentation/chat/photo_preview_edit_page.dart
import 'dart:io';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:html/parser.dart' as html_parser;

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';

// ============================================================================
// CONSTANTS
// ============================================================================
const int _kMaxCaptionLength = 500;
const int _kMaxImages = 10;
const int _kMaxImageSizeBytes = 20 * 1024 * 1024; // 20MB

// ============================================================================
// VALIDATORS
// ============================================================================
class _PreviewValidators {
  _PreviewValidators._();

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

  static bool isValidImageSize(int bytes) => bytes > 0 && bytes <= _kMaxImageSizeBytes;
}

// ============================================================================
// MAIN WIDGET
// ============================================================================
class PhotoPreviewEditPage extends StatefulWidget {
  final dynamic imageFile;
  final dynamic attachments;
  final Function(String caption)? onSend;
  final int initialIndex;

  const PhotoPreviewEditPage({
    super.key,
    this.imageFile,
    this.attachments,
    this.onSend,
    this.initialIndex = 0,
  });

  @override
  State<PhotoPreviewEditPage> createState() => _PhotoPreviewEditPageState();
}

class _PhotoPreviewEditPageState extends State<PhotoPreviewEditPage> {
  final TextEditingController _captionController = TextEditingController();
  final FocusNode _captionFocusNode = FocusNode();
  bool _isSending = false;
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    debugPrint('[PhotoPreview] 📷 Opened with initialIndex=${widget.initialIndex}');
    _pageController = PageController(initialPage: widget.initialIndex);
    _currentPage = widget.initialIndex;
    _pageController.addListener(_onPageChanged);
  }

  @override
  void dispose() {
    _captionController.dispose();
    _captionFocusNode.dispose();
    _pageController.removeListener(_onPageChanged);
    _pageController.dispose();
    debugPrint('[PhotoPreview] 👋 Disposed');
    super.dispose();
  }

  void _onPageChanged() {
    if (_pageController.hasClients && mounted) {
      final page = _pageController.page?.round() ?? 0;
      if (page != _currentPage) {
        setState(() => _currentPage = page);
      }
    }
  }

  Future<void> _handleSend() async {
    if (_isSending) {
      debugPrint('[PhotoPreview] ⚠️ Already sending');
      return;
    }

    final caption = _PreviewValidators.sanitize(
      _captionController.text,
      maxLength: _kMaxCaptionLength,
    );

    if (!mounted) return;

    setState(() => _isSending = true);
    HapticFeedback.mediumImpact();
    debugPrint('[PhotoPreview] 📤 Sending with caption (${caption.length} chars)');

    try {
      Navigator.pop(context, caption);
      widget.onSend?.call(caption);
      debugPrint('[PhotoPreview] ✓ Sent successfully');
    } catch (e) {
      debugPrint('[PhotoPreview] ❌ Send error: $e');
      if (mounted) {
        setState(() => _isSending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).t('preview_send_error')),
            backgroundColor: ThixPolicy.danger,
          ),
        );
      }
    }
  }

  Future<bool> _handleWillPop() async {
    if (_captionController.text.trim().isEmpty) return true;

    final l10n = AppLocalizations.of(context);
    HapticFeedback.lightImpact();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rLg)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: ThixPolicy.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.warning_rounded, color: ThixPolicy.warning, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                l10n.t('preview_discard_title'),
                style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold, fontSize: 16),
              ),
            ),
          ],
        ),
        content: Text(l10n.t('preview_discard_message'), style: ThixPolicy.bodyStyle),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.t('common_cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: ThixPolicy.danger,
              foregroundColor: Colors.white,
            ),
            child: Text(l10n.t('preview_discard')),
          ),
        ],
      ),
    );

    return confirmed ?? false;
  }

  void _handleCaptionSubmitted(String value) {
    if (value.trim().isEmpty) return;
    _handleSend();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return WillPopScope(
      onWillPop: _handleWillPop,
      child: Scaffold(
        backgroundColor: ThixPolicy.textMain, // Dark background for preview
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.white),
          leading: Semantics(
            button: true,
            label: l10n.t('common_back'),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              onPressed: () {
                HapticFeedback.selectionClick();
                Navigator.pop(context);
              },
            ),
          ),
          title: Text(
            l10n.t('preview_title'),
            style: ThixPolicy.labelStyle.copyWith(
              color: Colors.white,
              fontSize: 16,
              fontWeight: ThixPolicy.bold,
            ),
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: RepaintBoundary(
                child: Center(
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: _buildImageWidget(),
                  ),
                ),
              ),
            ),
            _CaptionBar(
              controller: _captionController,
              focusNode: _captionFocusNode,
              isSending: _isSending,
              onSend: _handleSend,
              onSubmitted: _handleCaptionSubmitted,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageWidget() {
    final target = widget.attachments ?? widget.imageFile;
    if (target == null) {
      return _buildEmptyState();
    }

    var images = <dynamic>[];
    if (target is List && target.isNotEmpty) {
      images = target.take(_kMaxImages).toList(); // Limiter à 10 images max
    } else {
      images = [target];
    }

    if (images.isEmpty) {
      return _buildEmptyState();
    }

    if (images.length > 1) {
      return PageView.builder(
        controller: _pageController,
        itemCount: images.length,
        itemBuilder: (context, index) => _buildSingleImage(images[index]),
      );
    } else {
      return _buildSingleImage(images.first);
    }
  }

  Widget _buildEmptyState() {
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.broken_image_rounded, color: Colors.white54, size: 64),
        const SizedBox(height: 16),
        Text(
          l10n.t('preview_no_image'),
          style: ThixPolicy.labelStyle.copyWith(color: Colors.white70, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildSingleImage(dynamic img) {
    if (kIsWeb) {
      if (img is String) {
        final sanitizedUrl = _PreviewValidators.sanitizeUrl(img);
        if (sanitizedUrl == null) return _buildInvalidImageState();
        return CachedNetworkImage(
          imageUrl: sanitizedUrl,
          fit: BoxFit.contain,
          placeholder: (_, __) => _buildLoadingState(),
          errorWidget: (_, __, ___) => _buildErrorState(),
        );
      } else if (img is Uint8List) {
        if (!_PreviewValidators.isValidImageSize(img.length)) {
          return _buildInvalidImageState();
        }
        return Image.memory(img, fit: BoxFit.contain);
      }
    } else {
      if (img is File) {
        if (!_PreviewValidators.isValidImageSize(img.lengthSync())) {
          return _buildInvalidImageState();
        }
        return Image.file(img, fit: BoxFit.contain);
      } else if (img is String) {
        if (img.startsWith('http')) {
          final sanitizedUrl = _PreviewValidators.sanitizeUrl(img);
          if (sanitizedUrl == null) return _buildInvalidImageState();
          return CachedNetworkImage(
            imageUrl: sanitizedUrl,
            fit: BoxFit.contain,
            placeholder: (_, __) => _buildLoadingState(),
            errorWidget: (_, __, ___) => _buildErrorState(),
          );
        } else {
          final file = File(img);
          if (!file.existsSync() || !_PreviewValidators.isValidImageSize(file.lengthSync())) {
            return _buildInvalidImageState();
          }
          return Image.file(file, fit: BoxFit.contain);
        }
      }
    }
    return _buildInvalidImageState();
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(color: Colors.white),
    );
  }

  Widget _buildErrorState() {
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.error_outline_rounded, color: Colors.white54, size: 64),
        const SizedBox(height: 16),
        Text(
          l10n.t('preview_load_error'),
          style: ThixPolicy.labelStyle.copyWith(color: Colors.white70, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildInvalidImageState() {
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.warning_rounded, color: Colors.white54, size: 64),
        const SizedBox(height: 16),
        Text(
          l10n.t('preview_invalid_image'),
          style: ThixPolicy.labelStyle.copyWith(color: Colors.white70, fontSize: 14),
        ),
      ],
    );
  }
}

// ============================================================================
// CAPTION BAR COMPONENT
// ============================================================================
class _CaptionBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isSending;
  final VoidCallback onSend;
  final ValueChanged<String> onSubmitted;

  const _CaptionBar({
    required this.controller,
    required this.focusNode,
    required this.isSending,
    required this.onSend,
    required this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        24 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: ThixPolicy.surface,
        border: Border(top: BorderSide(color: ThixPolicy.border, width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              label: l10n.t('preview_caption_label'),
              textField: true,
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                maxLength: _kMaxCaptionLength,
                textInputAction: TextInputAction.send,
                onSubmitted: onSubmitted,
                style: ThixPolicy.bodyStyle.copyWith(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  counterText: '', // Masquer le compteur
                  hintText: l10n.t('preview_caption_hint'),
                  hintStyle: ThixPolicy.bodyStyle.copyWith(color: Colors.white54),
                  filled: true,
                  fillColor: ThixPolicy.textMain.withOpacity(0.1),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: ThixPolicy.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: ThixPolicy.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(color: ThixPolicy.primary, width: 1.5),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Semantics(
            button: true,
            label: l10n.t('common_send'),
            enabled: !isSending,
            child: CircleAvatar(
              radius: 24,
              backgroundColor: isSending
                  ? ThixPolicy.primary.withOpacity(0.5)
                  : ThixPolicy.primary,
              child: IconButton(
                icon: isSending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                onPressed: isSending ? null : onSend,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
