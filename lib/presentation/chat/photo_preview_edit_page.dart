// lib/presentation/chat/photo_preview_edit_page.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class _C {
  static const bg = Color(0xFF0F172A);
  static const surface = Color(0xFF1E293B);
  static const primary = Color(0xFF1D4ED8);
  static const textMain = Colors.white;
  static const textMuted = Color(0xFF94A3B8);
  static const border = Color(0xFF334155);
}

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
  bool _isSending = false;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _captionController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _handleSend() {
    if (_isSending) return;
    setState(() => _isSending = true);
    Navigator.pop(context, _captionController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: _C.textMain),
        title: const Text(
          'Aperçu de l\'image',
          style: TextStyle(color: _C.textMain, fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: _buildImageWidget(),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            decoration: const BoxDecoration(
              color: _C.surface,
              border: Border(top: BorderSide(color: _C.border, width: 1)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _captionController,
                    style: const TextStyle(color: _C.textMain, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Ajouter une légende...',
                      hintStyle: const TextStyle(color: _C.textMuted),
                      filled: true,
                      fillColor: _C.bg,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: _C.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: _C.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: _C.primary),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                CircleAvatar(
                  radius: 24,
                  backgroundColor: _C.primary,
                  child: IconButton(
                    icon: _isSending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                    onPressed: _handleSend,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageWidget() {
    final target = widget.attachments ?? widget.imageFile;
    if (target == null) {
      return const Icon(Icons.broken_image, color: _C.textMuted, size: 64);
    }

    var images = <dynamic>[];
    if (target is List && target.isNotEmpty) {
      images = target;
    } else {
      images = [target];
    }

    if (images.isEmpty) {
      return const Icon(Icons.broken_image, color: _C.textMuted, size: 64);
    }

    // Build PageView for multiple images or single image
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

  Widget _buildSingleImage(dynamic img) {
    if (kIsWeb) {
      if (img is String) {
        return Image.network(img, fit: BoxFit.contain);
      } else if (img is Uint8List) {
        return Image.memory(img, fit: BoxFit.contain);
      }
    } else {
      if (img is File) {
        return Image.file(img, fit: BoxFit.contain);
      } else if (img is String) {
        if (img.startsWith('http')) {
          return Image.network(img, fit: BoxFit.contain);
        } else {
          return Image.file(File(img), fit: BoxFit.contain);
        }
      }
    }
    return const Icon(Icons.broken_image, color: _C.textMuted, size: 64);
  }
}
