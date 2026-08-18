import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:thix_id/services/network_service.dart';

class CreatePostSheet extends StatefulWidget {
  final String profileId;

  const CreatePostSheet({Key? key, required this.profileId}) : super(key: key);

  static Future<void> show(BuildContext context, {required String profileId}) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: CreatePostSheet(profileId: profileId),
      ),
    );
  }

  @override
  State<CreatePostSheet> createState() => _CreatePostSheetState();
}

class _CreatePostSheetState extends State<CreatePostSheet> {
  final _controller = TextEditingController();
  List<PlatformFile> _picked = [];
  bool _loading = false;

  Future<void> _pickFiles() async {
    final res = await FilePicker.platform.pickFiles(allowMultiple: true, type: FileType.image, withData: true);
    if (res == null) return;
    setState(() => _picked = res.files);
  }

  Future<void> _submit() async {
    final content = _controller.text.trim();
    if (content.isEmpty && _picked.isEmpty) return;
    setState(() => _loading = true);
    try {
      final networkService = context.read<NetworkService>();
      final imageUrls = <String>[];

      // Uploader les images sélectionnées
      for (final file in _picked) {
        final bytes = file.bytes;
        if (bytes == null) continue;
        final ext = (file.extension?.trim().isNotEmpty == true) ? file.extension!.toLowerCase() : 'jpg';
        // ✅ Correction : utiliser fileExtension au lieu de extension
        final url = await networkService.uploadImageBytes(bytes, fileExtension: ext);
        if (url != null && url.isNotEmpty) {
          imageUrls.add(url);
        }
      }

      // Créer le post avec le contenu et les URLs des images
      final postId = await networkService.createPost(content, imageUrls);

      if (postId.isNotEmpty && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Publication réussie !'), backgroundColor: Colors.green),
        );
        context.pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors de la publication')),
        );
      }
    } catch (e) {
      debugPrint('CreatePostSheet error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la publication: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Créer une publication',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          TextField(
            controller: _controller,
            maxLines: null,
            decoration: const InputDecoration(
              hintText: 'Que voulez-vous partager ?',
            ),
          ),
          const SizedBox(height: 12),
          if (_picked.isNotEmpty)
            SizedBox(
              height: 96,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _picked.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final p = _picked[i];
                  return Stack(
                    children: [
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.grey[200],
                        ),
                        child: p.bytes != null
                            ? Image.memory(p.bytes!, fit: BoxFit.cover)
                            : Center(
                                child: Icon(
                                  Icons.image,
                                  color: Colors.grey[500],
                                ),
                              ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => setState(() => _picked.removeAt(i)),
                          child: const CircleAvatar(
                            radius: 12,
                            child: Icon(Icons.close, size: 14),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              TextButton.icon(
                onPressed: _pickFiles,
                icon: const Icon(Icons.photo_library),
                label: const Text('Photos'),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Publier'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
