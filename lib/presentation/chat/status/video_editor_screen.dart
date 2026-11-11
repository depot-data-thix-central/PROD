//lib/presentation/chat/status/video_editor_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

class VideoEditorScreen extends StatelessWidget {
  final File videoFile;
  const VideoEditorScreen({super.key, required this.videoFile});

  @override
  Widget build(BuildContext context) {
    return ProVideoEditor.file(
      videoFile,
      configs: ProVideoEditorConfigs(
        videoPlayerConfigs: VideoPlayerConfigs(showControls: true),
      ),
      onComplete: (File editedVideo) {
        Navigator.pop(context, editedVideo);
      },
      onCancel: () {
        Navigator.pop(context);
      },
    );
  }
}
