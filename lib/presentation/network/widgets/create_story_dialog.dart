// lib/presentation/network/widgets/create_story_dialog.dart
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:thix_id/features/network/data/network_service_provider.dart';

// ✅ Design System THIX v1
import 'package:thix_id/core/theme/thix_design_policy.dart';

class CreateStoryDialog extends ConsumerStatefulWidget {
  const CreateStoryDialog({super.key});
  @override
  ConsumerState<CreateStoryDialog> createState() => _CreateStoryDialogState();
}

class _CreateStoryDialogState extends ConsumerState<CreateStoryDialog> {
  final _textController = TextEditingController();
  Uint8List? _mediaBytes;
  String? _mediaExt;
  String? _mediaType; // image | video
  bool _isUploading = false;
  final int _duration = 24;

  final _picker = ImagePicker();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
      if (result?.files.first.bytes != null) {
        final f = result!.files.first;
        if (f.size > 10 * 1024 * 1024) {
          _showError('Image > 10 Mo');
          return;
        }
        setState(() {
          _mediaBytes = f.bytes;
          _mediaExt = f.extension ?? 'jpg';
          _mediaType = 'image';
        });
      }
    } catch (e) {
      debugPrint('pickImage $e');
    }
  }

  Future<void> _pickVideo() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.video, withData: !kIsWeb);
      if (result == null) return;
      final f = result.files.first;
      if (f.size > 50 * 1024 * 1024) {
        _showError('Vidéo > 50 Mo');
        return;
      }
      Uint8List? bytes = f.bytes;
      if (bytes == null && kIsWeb) {
        _showError('Vidéo trop lourde pour le Web');
        return;
      }
      setState(() {
        _mediaBytes = bytes ?? f.bytes;
        _mediaExt = f.extension ?? 'mp4';
        _mediaType = 'video';
      });
    } catch (e) {
      debugPrint('pickVideo $e');
      _showError('Erreur vidéo');
    }
  }

  Future<void> _recordShortVideo() async {
    if (kIsWeb) {
      _showError('Caméra non supportée sur Web');
      return;
    }
    try {
      final XFile? video = await _picker.pickVideo(source: ImageSource.camera, maxDuration: const Duration(seconds: 45));
      if (video != null) {
        final bytes = await video.readAsBytes();
        if (bytes.lengthInBytes > 50 * 1024 * 1024) {
          _showError('Vidéo > 50 Mo');
          return;
        }
        setState(() {
          _mediaBytes = bytes;
          _mediaExt = 'mp4';
          _mediaType = 'video';
        });
      }
    } catch (e) {
      debugPrint('record $e');
      _showError('Caméra indisponible');
    }
  }

  Future<void> _createStory() async {
    final text = _textController.text.trim();
    if (text.isEmpty && _mediaBytes == null) {
      _showError('Ajoutez du texte ou un média');
      return;
    }
    setState(() => _isUploading = true);
    try {
      final service = ref.read(networkServiceProvider);
      String? mediaUrl;
      if (_mediaBytes != null) {
        Uint8List uploadBytes = _mediaBytes!;
        
        // Compression directe sécurisée (évite les erreurs d'Isolate sur Web et Mobile)
        if (_mediaType == 'image' && !kIsWeb) {
          try {
            uploadBytes = await FlutterImageCompress.compressWithList(
              _mediaBytes!,
              minHeight: 1080,
              minWidth: 1080,
              quality: 85,
              rotate: 0,
            );
          } catch (compressError) {
            debugPrint('⚠️ Erreur compression (fallback original) : $compressError');
            uploadBytes = _mediaBytes!;
          }
        }

        mediaUrl = await service.uploadImageBytes(uploadBytes, fileExtension: _mediaExt ?? 'jpg', bucket: 'stories');
      }
      await service.createStory(mediaUrl, text: text, duration: _duration, mediaType: _mediaType ?? 'text');
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      debugPrint('createStory $e');
      _showError('Erreur publication: $e');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showError(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: ThixPolicy.danger));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rXl)),
      backgroundColor: ThixPolicy.card,
      insetPadding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16, vertical: ThixPolicy.s24),
      child: Container(
        width: MediaQuery.of(context).size.width,
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 650),
        padding: const EdgeInsets.all(ThixPolicy.s20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Créer une publication', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: ThixPolicy.textMain)),
                Container(
                  decoration: const BoxDecoration(color: ThixPolicy.surface, shape: BoxShape.circle),
                  child: IconButton(
                    icon: const Icon(Icons.close_rounded, color: ThixPolicy.textMain, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: ThixPolicy.s16),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(ThixPolicy.s16),
                decoration: BoxDecoration(
                  color: ThixPolicy.surface,
                  borderRadius: BorderRadius.circular(ThixPolicy.rLg),
                  border: Border.all(color: ThixPolicy.border),
                ),
                child: TextField(
                  controller: _textController,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  style: const TextStyle(color: ThixPolicy.textMain, fontSize: 15),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: "Quoi de neuf dans votre monde pro ?",
                    hintStyle: TextStyle(color: ThixPolicy.textSecondary.withOpacity(0.6)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: ThixPolicy.s12),
            if (_mediaBytes != null)
              Stack(
                children: [
                  Container(
                    height: 80,
                    width: 80,
                    margin: const EdgeInsets.only(bottom: ThixPolicy.s12),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                      image: _mediaType == 'image' ? DecorationImage(image: MemoryImage(_mediaBytes!), fit: BoxFit.cover) : null,
                    ),
                    child: _mediaType == 'video' ? const Center(child: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 36)) : null,
                  ),
                  Positioned(
                    top: -8,
                    right: -8,
                    child: IconButton(
                      icon: const Icon(Icons.cancel_rounded, color: ThixPolicy.textMain),
                      onPressed: () => setState(() {
                        _mediaBytes = null;
                        _mediaType = null;
                      }),
                    ),
                  ),
                ],
              ),
            Row(
              children: [
                _buildMediaIcon(Icons.image_rounded, ThixPolicy.success, _pickImage, "Photo"),
                const SizedBox(width: ThixPolicy.s8),
                _buildMediaIcon(Icons.folder_shared_rounded, ThixPolicy.warning, _pickVideo, "Vidéo"),
                const SizedBox(width: ThixPolicy.s8),
                _buildMediaIcon(Icons.videocam_rounded, ThixPolicy.danger, _recordShortVideo, "Caméra"),
              ],
            ),
            const SizedBox(height: ThixPolicy.s16),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _isUploading ? null : _createStory,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ThixPolicy.gold,
                  foregroundColor: ThixPolicy.inkDeep,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rLg)),
                ),
                child: _isUploading
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: ThixPolicy.inkDeep, strokeWidth: 2))
                    : const Text('PUBLIER', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 0.5)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaIcon(IconData icon, Color c, VoidCallback onTap, String tooltip) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ThixPolicy.rSm),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: ThixPolicy.surface,
            borderRadius: BorderRadius.circular(ThixPolicy.rSm),
            border: Border.all(color: ThixPolicy.border),
          ),
          child: Icon(icon, color: c, size: 24),
        ),
      ),
    );
  }
}
