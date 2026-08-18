// Route: lib/presentation/chat/call/widgets/local_video_preview.dart
// PRODUCTION - Local PIP draggable - Mirror - Cam Off state
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';

class LocalVideoPreview extends StatefulWidget {
  final String channel;
  final bool videoOff;
  final bool isFrontCamera;

  const LocalVideoPreview({
    super.key,
    required this.channel,
    this.videoOff = false,
    this.isFrontCamera = true,
  });

  @override
  State<LocalVideoPreview> createState() => _LocalVideoPreviewState();
}

class _LocalVideoPreviewState extends State<LocalVideoPreview> {
  Offset _offset = const Offset(0, 0);
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 90 + _offset.dy,
      right: 16 - _offset.dx,
      child: GestureDetector(
        onPanStart: (_) => setState(() => _isDragging = true),
        onPanUpdate: (details) {
          setState(() {
            _offset += details.delta;
            // Limites pour ne pas sortir de l'écran
            _offset = Offset(
              _offset.dx.clamp(-180, 20),
              _offset.dy.clamp(-40, 400),
            );
          });
        },
        onPanEnd: (_) => setState(() => _isDragging = false),
        child: AnimatedScale(
          scale: _isDragging ? 1.05 : 1.0,
          duration: const Duration(milliseconds: 150),
          child: Container(
            width: 112,
            height: 168,
            decoration: BoxDecoration(
              color: const Color(0xFF0A1F44),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _isDragging ? const Color(0xFFE3B23C) : Colors.white24,
                width: _isDragging ? 1.6 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(_isDragging ? 0.55 : 0.35),
                  blurRadius: _isDragging ? 18 : 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // VIDEO ou CAM OFF
                  if (!widget.videoOff)
                    AgoraVideoView(
                      controller: VideoViewController(
                        rtcConnection: RtcConnection(channelId: widget.channel),
                        canvas: VideoCanvas(
                          uid: 0,
                          renderMode: RenderModeType.renderModeHidden,
                          mirrorMode: widget.isFrontCamera
                              ? VideoMirrorModeType.videoMirrorModeEnabled
                              : VideoMirrorModeType.videoMirrorModeDisabled,
                        ),
                      ),
                    )
                  else
                    Container(
                      color: const Color(0xFF0D2244),
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.videocam_off_rounded,
                                color: Colors.white38, size: 26),
                            SizedBox(height: 6),
                            Text('Caméra off',
                                style: TextStyle(
                                    color: Colors.white38,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),

                  // Label Vous
                  Positioned(
                    left: 6,
                    bottom: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.60),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.12)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.person_rounded,
                              size: 9, color: Colors.white70),
                          SizedBox(width: 3),
                          Text('Vous',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.2)),
                        ],
                      ),
                    ),
                  ),

                  // Drag handle quand on drag
                  if (_isDragging)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.55),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.open_with_rounded,
                            size: 10, color: Colors.white70),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
