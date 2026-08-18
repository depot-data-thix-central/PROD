// lib/presentation/network/live/live_broadcast_screen.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/data/models/live/live_model.dart';
import 'package:thix_id/presentation/network/live/live_controller.dart';

class _C {
  static const primary = ThixPolicy.primary;
  static const red = ThixPolicy.danger;
  static const bgDark = ThixPolicy.inkDeep;
  static const textMain = Colors.white;
  static const textMuted = Colors.white70;
}

class LiveBroadcastScreen extends ConsumerStatefulWidget {
  final LiveSession session;
  final bool isVideoEnabled;
  final bool isMicEnabled;

  const LiveBroadcastScreen({
    super.key,
    required this.session,
    required this.isVideoEnabled,
    required this.isMicEnabled,
  });

  @override
  ConsumerState<LiveBroadcastScreen> createState() => _LiveBroadcastScreenState();
}

class _LiveBroadcastScreenState extends ConsumerState<LiveBroadcastScreen> {
  final TextEditingController _chatController = TextEditingController();
  final List<Widget> _floatingHearts = [];
  final Random _random = Random();
  bool _listenersAttached = false;

  void _attachListenersOnce() {
    if (_listenersAttached) return;
    _listenersAttached = true;

    final notifier = ref.read(liveControllerProvider(widget.session).notifier);
    notifier.onCoHostRequest = _handleCoHostRequest;
    notifier.heartStream.listen((_) => _spawnHeart());

    // Applique les préférences initiales caméra/micro passées au widget.
    notifier.bootstrap(
      initialVideoEnabled: widget.isVideoEnabled,
      initialMicEnabled: widget.isMicEnabled,
    );
  }

  void _handleCoHostRequest(String requestUserId, String requestUserName) {
    if (!mounted) return;
    final notifier = ref.read(liveControllerProvider(widget.session).notifier);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _C.bgDark,
        title: const Text('Demande de participation', style: TextStyle(color: _C.textMain)),
        content: Text('$requestUserName souhaite rejoindre le direct en vidéo.', style: const TextStyle(color: _C.textMuted)),
        actions: [
          TextButton(
            onPressed: () {
              notifier.respondToCoHost(requestUserId, false);
              Navigator.pop(ctx);
            },
            child: const Text('Refuser', style: TextStyle(color: _C.red)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _C.primary),
            onPressed: () {
              notifier.respondToCoHost(requestUserId, true);
              Navigator.pop(ctx);
            },
            child: const Text('Accepter', style: TextStyle(color: _C.textMain)),
          ),
        ],
      ),
    );
  }

  void _spawnHeart() {
    if (!mounted) return;
    final key = UniqueKey();
    setState(() {
      _floatingHearts.add(_AnimatedHeart(
        key: key,
        color: Colors.primaries[_random.nextInt(Colors.primaries.length)],
        onComplete: () {
          if (!mounted) return;
          setState(() => _floatingHearts.removeWhere((w) => w.key == key));
        },
      ));
    });
  }

  void _sendComment() {
    if (_chatController.text.trim().isEmpty) return;
    ref.read(liveControllerProvider(widget.session).notifier).sendComment(_chatController.text);
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
    // build() est appelé à chaque frame ; on n'attache les listeners qu'une fois.
    _attachListenersOnce();

    final state = ref.watch(liveControllerProvider(widget.session));
    final notifier = ref.read(liveControllerProvider(widget.session).notifier);

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        await notifier.endBroadcast();
        if (context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: _C.bgDark,
        resizeToAvoidBottomInset: true,
        body: Stack(
          children: [
            Positioned.fill(child: _buildBackground(context, state, notifier)),

            if (state.status == LiveScreenStatus.ready) ...[
              Positioned(top: 0, left: 0, right: 0, height: 140, child: Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black.withOpacity(0.6), Colors.transparent])))),
              Positioned(bottom: 0, left: 0, right: 0, height: 350, child: Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black.withOpacity(0.8), Colors.transparent])))),

              if (state.coHostUids.isNotEmpty)
                Positioned(
                  top: 100, right: 16,
                  child: Column(
                    children: state.coHostUids.map((uid) => Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      width: 100, height: 140,
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: _C.primary, width: 2), color: Colors.black),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: AgoraVideoView(
                          controller: VideoViewController.remote(
                            rtcEngine: notifier.engine!, canvas: VideoCanvas(uid: uid), connection: RtcConnection(channelId: widget.session.channelName), useFlutterTexture: kIsWeb,
                          ),
                        ),
                      ),
                    )).toList(),
                  ),
                ),

              _buildTopBar(context, state, notifier),

              Positioned(
                right: 16, bottom: 160,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _SideActionButton(
                      icon: state.isBeautyEnabled ? Icons.face_retouching_natural_rounded : Icons.face_rounded,
                      label: 'Beauté',
                      color: state.isBeautyEnabled ? _C.primary : _C.textMain,
                      onTap: notifier.toggleBeauty,
                    ),
                  ],
                ),
              ),

              Positioned(
                left: 16, bottom: 160, width: MediaQuery.of(context).size.width * 0.7, height: 250,
                child: ShaderMask(
                  shaderCallback: (Rect bounds) => const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.white, Colors.white], stops: [0.0, 0.2, 1.0]).createShader(bounds),
                  blendMode: BlendMode.dstIn,
                  child: ListView.builder(
                    reverse: true,
                    itemCount: state.comments.length,
                    itemBuilder: (context, index) {
                      final comment = state.comments[state.comments.length - 1 - index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(16)),
                          child: RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(text: '${comment.userName}   ', style: TextStyle(color: _C.textMain.withOpacity(0.6), fontWeight: FontWeight.bold, fontSize: 13)),
                                TextSpan(text: comment.text, style: const TextStyle(color: _C.textMain, fontSize: 14)),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              Positioned(
                left: 16, right: 16, bottom: 90,
                child: SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 44,
                          decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(ThixPolicy.rFull)),
                          child: TextField(
                            controller: _chatController,
                            style: const TextStyle(color: _C.textMain, fontSize: 14),
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _sendComment(),
                            decoration: const InputDecoration(hintText: 'Ajouter un commentaire...', hintStyle: TextStyle(color: _C.textMuted), border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              Positioned(
                left: 0, right: 0, bottom: 0,
                child: Container(
                  padding: const EdgeInsets.only(bottom: 24, top: 12, left: 16, right: 16),
                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _BottomControlButton(
                        icon: state.isVideoOff ? Icons.videocam_off_rounded : Icons.videocam_rounded,
                        label: state.isVideoOff ? 'Cam off' : 'Caméra',
                        color: state.isVideoOff ? _C.red : _C.textMain,
                        onTap: notifier.toggleVideo,
                      ),
                      _BottomControlButton(
                        icon: state.isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                        label: state.isMuted ? 'Muet' : 'Micro',
                        color: state.isMuted ? _C.red : _C.textMain,
                        onTap: notifier.toggleMute,
                      ),
                      _BottomControlButton(
                        icon: Icons.flip_camera_ios_rounded,
                        label: 'Tourner',
                        onTap: notifier.switchCamera,
                      ),
                      _BottomControlButton(
                        icon: Icons.favorite_rounded,
                        label: "J'aime",
                        color: _C.primary,
                        onTap: notifier.triggerHeart,
                      ),
                    ],
                  ),
                ),
              ),

              ..._floatingHearts,
            ] else
              _buildMinimalTopBar(context, notifier),
          ],
        ),
      ),
    );
  }

  Widget _buildBackground(BuildContext context, LiveState state, LiveController notifier) {
    switch (state.status) {
      case LiveScreenStatus.ready:
        if (state.isVideoOff || notifier.engine == null) {
          return Container(color: _C.bgDark);
        }
        return SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.height,
              child: AgoraVideoView(
                controller: VideoViewController(
                  rtcEngine: notifier.engine!, canvas: const VideoCanvas(uid: 0), useFlutterTexture: kIsWeb,
                ),
              ),
            ),
          ),
        );

      case LiveScreenStatus.loading:
        return Container(
          color: _C.bgDark,
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: _C.primary),
                SizedBox(height: 16),
                Text("Connexion au direct en cours...", style: TextStyle(color: _C.textMuted)),
              ],
            ),
          ),
        );

      case LiveScreenStatus.permissionDenied:
        return Container(
          color: _C.bgDark,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.no_photography_rounded, color: _C.red, size: 40),
                  const SizedBox(height: 16),
                  const Text(
                    "Autorisation caméra/micro requise pour démarrer le direct.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _C.textMain, fontSize: 14),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: _C.primary),
                    onPressed: () => openAppSettings(),
                    child: const Text('Ouvrir les réglages'),
                  ),
                  TextButton(
                    onPressed: () => notifier.bootstrap(
                      initialVideoEnabled: widget.isVideoEnabled,
                      initialMicEnabled: widget.isMicEnabled,
                    ),
                    child: const Text('Réessayer', style: TextStyle(color: _C.textMuted)),
                  ),
                ],
              ),
            ),
          ),
        );

      case LiveScreenStatus.error:
        return Container(
          color: _C.bgDark,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline_rounded, color: _C.red, size: 40),
                  const SizedBox(height: 16),
                  Text(
                    "Erreur d'initialisation :\n${state.errorMessage ?? 'Inconnue'}",
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: _C.red, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: _C.primary),
                    onPressed: () => notifier.bootstrap(
                      initialVideoEnabled: widget.isVideoEnabled,
                      initialMicEnabled: widget.isMicEnabled,
                    ),
                    child: const Text('Réessayer'),
                  ),
                ],
              ),
            ),
          ),
        );
    }
  }

  Widget _buildMinimalTopBar(BuildContext context, LiveController notifier) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            const Spacer(),
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                child: const Icon(Icons.close_rounded, color: _C.textMain, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, LiveState state, LiveController notifier) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(30)),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: _C.primary,
                    backgroundImage: widget.session.hostAvatarUrl != null && widget.session.hostAvatarUrl!.isNotEmpty
                        ? CachedNetworkImageProvider(widget.session.hostAvatarUrl!)
                        : null,
                    child: widget.session.hostAvatarUrl == null || widget.session.hostAvatarUrl!.isEmpty
                        ? const Icon(Icons.person, size: 20, color: _C.textMain)
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(widget.session.hostName, style: const TextStyle(color: _C.textMain, fontSize: 13, fontWeight: FontWeight.bold)),
                      Row(
                        children: [
                          Container(width: 6, height: 6, decoration: const BoxDecoration(color: _C.red, shape: BoxShape.circle)),
                          const SizedBox(width: 4),
                          const Text('EN DIRECT', style: TextStyle(color: _C.textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                ],
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(ThixPolicy.rFull)),
              child: Row(children: [const Icon(Icons.visibility_rounded, color: _C.textMain, size: 14), const SizedBox(width: 4), Text('${state.viewerCount}', style: const TextStyle(color: _C.textMain, fontSize: 13, fontWeight: FontWeight.bold))]),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () async {
                await notifier.endBroadcast();
                if (context.mounted) Navigator.of(context).pop();
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                child: state.isEnding ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: _C.textMain, strokeWidth: 2)) : const Icon(Icons.close_rounded, color: _C.textMain, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── COMPOSANTS ANNEXES ───

class _SideActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  const _SideActionButton({required this.icon, required this.label, required this.onTap, this.color = _C.textMain});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GestureDetector(
        onTap: onTap,
        child: Column(children: [
          Container(padding: const EdgeInsets.all(10), decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle), child: Icon(icon, color: color, size: 22)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: _C.textMain, fontSize: 10, fontWeight: FontWeight.w600, shadows: [Shadow(color: Colors.black54, blurRadius: 2)])),
        ]),
      ),
    );
  }
}

class _BottomControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  const _BottomControlButton({required this.icon, required this.label, required this.onTap, this.color = Colors.white});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _AnimatedHeart extends StatefulWidget {
  final Color color;
  final VoidCallback onComplete;
  const _AnimatedHeart({super.key, required this.color, required this.onComplete});
  @override
  State<_AnimatedHeart> createState() => _AnimatedHeartState();
}

class _AnimatedHeartState extends State<_AnimatedHeart> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _pos, _op, _sc;
  final _r = Random();
  late double _x;

  @override
  void initState() {
    super.initState();
    _x = (_r.nextDouble() * 60) - 30;
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000));
    _pos = Tween<double>(begin: 0, end: 400).animate(CurvedAnimation(parent: _c, curve: Curves.easeOut));
    _op = Tween<double>(begin: 1.0, end: 0.0).animate(CurvedAnimation(parent: _c, curve: const Interval(0.5, 1.0, curve: Curves.easeOut)));
    _sc = Tween<double>(begin: 0.5, end: 1.5).animate(CurvedAnimation(parent: _c, curve: Curves.elasticOut));
    _c.forward().then((_) => widget.onComplete());
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (c, _) => Positioned(
        bottom: 70 + _pos.value,
        right: 25 + _x + (sin(_pos.value / 30) * 20),
        child: Opacity(opacity: _op.value, child: Transform.scale(scale: _sc.value, child: Icon(Icons.favorite_rounded, color: widget.color, size: 28))),
      ),
    );
  }
}
