// lib/presentation/network/live/live_viewer_screen.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/data/models/live/live_model.dart';
import 'live_viewer_controller.dart';

class LiveViewerScreen extends ConsumerStatefulWidget {
  final LiveSession session;
  const LiveViewerScreen({super.key, required this.session});

  @override
  ConsumerState<LiveViewerScreen> createState() => _LiveViewerScreenState();
}

class _LiveViewerScreenState extends ConsumerState<LiveViewerScreen> {
  final TextEditingController _chatController = TextEditingController();

  void _sendComment() {
    if (_chatController.text.trim().isEmpty) return;
    ref.read(liveViewerControllerProvider(widget.session).notifier).sendComment(_chatController.text);
    _chatController.clear();
    FocusScope.of(context).unfocus();
  }

  @override
  void dispose() {
    _chatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(liveViewerControllerProvider(widget.session));
    final notifier = ref.read(liveViewerControllerProvider(widget.session).notifier);

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        await notifier.leaveLive();
        if (context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Positioned.fill(child: _buildBackground(state, notifier)),

            if (state.status == ViewerStatus.ready) ...[
              Positioned(
                top: 0, left: 0, right: 0, height: 140,
                child: Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black.withOpacity(0.7), Colors.transparent]))),
              ),
              Positioned(
                bottom: 0, left: 0, right: 0, height: 280,
                child: Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black.withOpacity(0.8), Colors.transparent]))),
              ),

              _buildTopBar(context, state),

              // Chat (lecture + envoi, pas de contrôles de diffusion)
              Positioned(
                left: 16, bottom: 90, width: MediaQuery.of(context).size.width * 0.75, height: 240,
                child: ShaderMask(
                  shaderCallback: (Rect bounds) => const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.white, Colors.white], stops: [0.0, 0.15, 1.0]).createShader(bounds),
                  blendMode: BlendMode.dstIn,
                  child: ListView.builder(
                    reverse: true,
                    physics: const BouncingScrollPhysics(),
                    itemCount: state.comments.length,
                    itemBuilder: (context, index) {
                      final comment = state.comments[state.comments.length - 1 - index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                                ),
                                child: RichText(
                                  text: TextSpan(
                                    children: [
                                      TextSpan(text: '${comment.userName}  ', style: ThixPolicy.labelStyle.copyWith(color: Colors.white70, fontWeight: ThixPolicy.bold)),
                                      TextSpan(text: comment.text, style: ThixPolicy.bodyStyle.copyWith(color: Colors.white)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              // Bottom dock : chat input uniquement (pas de mic/caméra/beauté)
              Positioned(
                left: 0, right: 0, bottom: 0,
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(ThixPolicy.rXl),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(ThixPolicy.rXl),
                            border: Border.all(color: Colors.white.withOpacity(0.2)),
                          ),
                          child: TextField(
                            controller: _chatController,
                            style: ThixPolicy.bodyStyle.copyWith(color: Colors.white),
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _sendComment(),
                            decoration: InputDecoration(
                              hintText: 'Commenter...',
                              hintStyle: ThixPolicy.bodyStyle.copyWith(color: Colors.white54),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.send_rounded, color: Colors.white70, size: 20),
                                onPressed: _sendComment,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBackground(LiveViewerState state, LiveViewerController notifier) {
    switch (state.status) {
      case ViewerStatus.ready:
        if (state.isHostVideoOff || notifier.engine == null || state.hostUid == null) {
          return Container(
            color: ThixPolicy.inkDeep,
            child: const Center(child: Icon(Icons.videocam_off_rounded, color: Colors.white24, size: 60)),
          );
        }
        return SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.height,
              child: AgoraVideoView(
                controller: VideoViewController.remote(
                  rtcEngine: notifier.engine!,
                  canvas: VideoCanvas(uid: state.hostUid!),
                  connection: RtcConnection(channelId: widget.session.channelName),
                  useFlutterTexture: kIsWeb,
                ),
              ),
            ),
          ),
        );

      case ViewerStatus.loading:
        return Container(
          color: ThixPolicy.inkDeep,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(color: ThixPolicy.primary),
                const SizedBox(height: 16),
                Text("Connexion au direct...", style: ThixPolicy.bodyStyle.copyWith(color: Colors.white70)),
              ],
            ),
          ),
        );

      case ViewerStatus.hostOffline:
        return Container(
          color: ThixPolicy.inkDeep,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.stop_circle_outlined, color: Colors.white54, size: 48),
                const SizedBox(height: 16),
                Text("Le direct est terminé.", style: ThixPolicy.h3Style.copyWith(color: Colors.white)),
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rMd))),
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Retour', style: ThixPolicy.buttonText),
                ),
              ],
            ),
          ),
        );

      case ViewerStatus.error:
        return Container(
          color: ThixPolicy.inkDeep,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline_rounded, color: ThixPolicy.danger, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    state.errorMessage ?? "Erreur inconnue",
                    textAlign: TextAlign.center,
                    style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.danger, fontWeight: ThixPolicy.bold),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rMd))),
                    onPressed: () => ref.read(liveViewerControllerProvider(widget.session).notifier).bootstrap(),
                    child: Text('Réessayer', style: ThixPolicy.buttonText),
                  ),
                ],
              ),
            ),
          ),
        );
    }
  }

  Widget _buildTopBar(BuildContext context, LiveViewerState state) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(4, 4, 16, 4),
                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.4), borderRadius: BorderRadius.circular(30), border: Border.all(color: Colors.white.withOpacity(0.1))),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: ThixPolicy.primary,
                        backgroundImage: widget.session.hostAvatarUrl != null && widget.session.hostAvatarUrl!.isNotEmpty
                            ? CachedNetworkImageProvider(widget.session.hostAvatarUrl!)
                            : null,
                        child: widget.session.hostAvatarUrl == null || widget.session.hostAvatarUrl!.isEmpty
                            ? const Icon(Icons.person, size: 20, color: Colors.white)
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(widget.session.hostName, style: ThixPolicy.labelStyle.copyWith(color: Colors.white, fontSize: 13, fontWeight: ThixPolicy.bold)),
                          Row(
                            children: [
                              Container(width: 6, height: 6, decoration: const BoxDecoration(color: ThixPolicy.danger, shape: BoxShape.circle)),
                              const SizedBox(width: 4),
                              Text('EN DIRECT', style: ThixPolicy.microStyle.copyWith(color: Colors.white70, fontSize: 9, fontWeight: ThixPolicy.bold, letterSpacing: 0.5)),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Spacer(),
            ClipRRect(
              borderRadius: BorderRadius.circular(ThixPolicy.rFull),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.4), borderRadius: BorderRadius.circular(ThixPolicy.rFull), border: Border.all(color: Colors.white.withOpacity(0.1))),
                  child: Row(
                    children: [
                      const Icon(Icons.visibility_rounded, color: Colors.white, size: 14),
                      const SizedBox(width: 6),
                      Text('${state.viewerCount}', style: ThixPolicy.labelStyle.copyWith(color: Colors.white, fontSize: 13, fontWeight: ThixPolicy.bold)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () async {
                await ref.read(liveViewerControllerProvider(widget.session).notifier).leaveLive();
                if (context.mounted) Navigator.of(context).pop();
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(ThixPolicy.rFull),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                    child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
