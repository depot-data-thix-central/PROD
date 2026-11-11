//lib/presentation/chat/status/image_editor_screen.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:path_provider/path_provider.dart';

class ImageEditorScreen extends StatefulWidget {
  final File imageFile;
  const ImageEditorScreen({super.key, required this.imageFile});

  @override
  State<ImageEditorScreen> createState() => _ImageEditorScreenState();
}

class _ImageEditorScreenState extends State<ImageEditorScreen> {
  bool _isSaving = false;

  Future<void> _handleDone(Uint8List bytes) async {
    setState(() => _isSaving = true);
    try {
      final tempDir = await getTemporaryDirectory();
      final tempPath = '${tempDir.path}/edited_image_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final editedFile = File(tempPath);
      await editedFile.writeAsBytes(bytes);
      if (mounted) Navigator.pop(context, editedFile);
    } catch (e) {
      debugPrint('Erreur sauvegarde image: $e');
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isSaving) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return ProImageEditor.file(
      widget.imageFile,
      configs: ProImageEditorConfigs(
        mainConfigs: MainConfigs(
          theme: ImageEditorTheme(
            background: BackgroundConfigs(color: Colors.black),
          ),
        ),
      ),
      onImageEditingComplete: _handleDone,
      onCloseEditor: () => Navigator.pop(context),
    );
  }
}
