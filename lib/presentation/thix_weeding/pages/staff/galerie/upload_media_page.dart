// lib/presentation/thix_weeding/pages/staff/galerie/upload_media_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

// SEUL PROVIDER UTILE ICI

import 'package:thix_id/presentation/thix_weeding/pages/staff/providers/thix_weeding_providers.dart';

class UploadMediaPage extends ConsumerStatefulWidget {
  final String weddingId;
  const UploadMediaPage({super.key, required this.weddingId});
  @override
  ConsumerState<UploadMediaPage> createState() => _UploadMediaPageState();
}

class _UploadMediaPageState extends ConsumerState<UploadMediaPage> {
  final List<XFile> _picked = [];
  final _captionCtrl = TextEditingController();
  final _picker = ImagePicker();
  bool _isLoading = false;

  @override
  void dispose() {
    _captionCtrl.dispose();
    super.dispose();
  }

  // ================= PICK =================

  Future<void> _pickPhotos() async {
    final files = await _picker.pickMultiImage(imageQuality: 80);
    if (files.isNotEmpty) setState(() => _picked.addAll(files));
  }

  Future<void> _pickVideo() async {
    final file = await _picker.pickVideo(source: ImageSource.gallery);
    if (file != null) setState(() => _picked.add(file));
  }

  void _removeAt(int index) => setState(() => _picked.removeAt(index));

  // ================= UPLOAD - Même logique que toi, juste clean =================

  Future<void> _uploadAll() async {
    if (_picked.isEmpty) return;
    setState(() => _isLoading = true);

    try {
      final supa = Supabase.instance.client;

      for (var xfile in _picked) {
        final file = File(xfile.path);
        final ext = xfile.path.split('.').last.toLowerCase();
        final fileName = '${widget.weddingId}/${DateTime.now().millisecondsSinceEpoch}_${xfile.name}';
        final isVideo = ['mp4', 'mov', 'avi', 'mkv'].contains(ext);

        await supa.storage.from('thix-weeding-gallery').upload(fileName, file);
        final publicUrl = supa.storage.from('thix-weeding-gallery').getPublicUrl(fileName);

        await supa.from('thix_weeding_gallery').insert({
          'wedding_id': widget.weddingId,
          'media_url': publicUrl,
          'media_type': isVideo ? 'video' : 'image',
          'caption': _captionCtrl.text.trim().isEmpty ? null : _captionCtrl.text.trim(),
        });
      }

      // Refresh SEULEMENT la galerie
      ref.invalidate(galleryProvider(widget.weddingId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${_picked.length} médias uploadés')));
        context.pop();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ================= UI =================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(title: const Text('Uploader médias'), backgroundColor: Colors.white),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _PickButtons(onPhotos: _pickPhotos, onVideo: _pickVideo),
          const SizedBox(height: 16),
          _CaptionField(controller: _captionCtrl),
          const SizedBox(height: 16),
          if (_picked.isNotEmpty) _PickedGrid(picked: _picked, onRemove: _removeAt),
          const SizedBox(height: 24),
          _UploadButton(isLoading: _isLoading, count: _picked.length, onPressed: _uploadAll),
          const SizedBox(height: 8),
          Text('Chaque média aura son ID uuid unique en DB après upload', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        ],
      ),
    );
  }
}

// ================= WIDGETS INTERNES =================

class _PickButtons extends StatelessWidget {
  final VoidCallback onPhotos; final VoidCallback onVideo;
  const _PickButtons({required this.onPhotos, required this.onVideo});
  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(child: OutlinedButton.icon(onPressed: onPhotos, icon: const Icon(Icons.photo_library), label: const Text('Photos'))),
        const SizedBox(width: 12),
        Expanded(child: OutlinedButton.icon(onPressed: onVideo, icon: const Icon(Icons.videocam), label: const Text('Vidéo'))),
      ]);
}

class _CaptionField extends StatelessWidget {
  final TextEditingController controller;
  const _CaptionField({required this.controller});
  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        decoration: InputDecoration(labelText: 'Légende (optionnelle)', filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
      );
}

class _PickedGrid extends StatelessWidget {
  final List<XFile> picked; final Function(int) onRemove;
  const _PickedGrid({required this.picked, required this.onRemove});
  @override
  Widget build(BuildContext context) => GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8),
        itemCount: picked.length,
        itemBuilder: (_, i) => Stack(fit: StackFit.expand, children: [
          ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(File(picked[i].path), fit: BoxFit.cover)),
          Positioned(top: 2, right: 2, child: GestureDetector(onTap: () => onRemove(i), child: Container(decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle), padding: const EdgeInsets.all(2), child: const Icon(Icons.close, size: 16, color: Colors.white)))),
        ]),
      );
}

class _UploadButton extends StatelessWidget {
  final bool isLoading; final int count; final VoidCallback onPressed;
  const _UploadButton({required this.isLoading, required this.count, required this.onPressed});
  @override
  Widget build(BuildContext context) => FilledButton.icon(
        onPressed: isLoading || count == 0? null : onPressed,
        icon: isLoading? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.cloud_upload),
        label: Text(isLoading? 'Upload en cours...' : 'Uploader $count médias'),
        style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      );
}
