// lib/presentation/network/live/live_broadcast_screen.dart
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:permission_handler/permission_handler.dart';

// ✅ POLICY THIX APPLIQUÉE
import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/data/models/live/live_model.dart';
import 'package:thix_id/presentation/network/live/live_controller.dart';

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

  // Palette restreinte pour les coeurs (Charte THIX)
  final List<Color> _heartColors = [
    ThixPolicy.danger,
    ThixPolicy.primary,
    ThixPolicy.gold,
    Colors.white,
  ];

  void _attachListenersOnce() {
    if (_listenersAttached) return;
    _listenersAttached = true;

    final notifier = ref.read(liveControllerProvider(widget.session).notifier);
    notifier.onCoHostRequest = _handleCoHostRequest;
    notifier.heartStream.listen((_) => _spawnHeart());

    notifier.bootstrap(
      initialVideoEnabled: widget.isVideoEnabled,
      initialMicEnabled: widget.isMicEnabled,
    );
  }

  void _handleCoHostRequest(String requestUserId, String requestUserName) {
    if (!mounted) return;
    final notifier = ref.read(liveControllerProvider(widget.session).notifier);
    
    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThixPolicy.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rLg)),
        title: Text('Demande de participation', style: ThixPolicy.h3Style.copyWith(color: ThixPolicy.textMain, fontWeight: ThixPolicy.bold)),
        content: Text('$requestUserName souhaite rejoindre le direct en vidéo.', style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textSecondary)),
        actions: [
          TextButton(
            onPressed: () {
              notifier.respondToCoHost(requestUserId, false);
              Navigator.pop(ctx);
            },
            child: Text('Refuser', style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.danger)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ThixPolicy.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rSm)),
              elevation: 0,
            ),
            onPressed: () {
              notifier.respondToCoHost(requestUserId, true);
              Navigator.pop(ctx);
            },
            child: Text('Accepter', style: ThixPolicy.labelStyle.copyWith(color: Colors.white)),
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
        color: _heartColors[_random.nextInt(_heartColors.length)],
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
        backgroundColor: Colors.black, // Toujours noir pour le fond vidéo
        resizeToAvoidBottomInset: true,
        body: Stack(
          children: [
            Positioned.fill(child: _buildBackground(context, state, notifier)),

            if (state.status == LiveScreenStatus.ready) ...[
              // ─── GRADIENTS POUR LA LISIBILITÉ ───
              Positioned(
                top: 0, left: 0, right: 0, height: 160, 
                child: Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black.withOpacity(0.7), Colors.transparent])))
              ),
              Positioned(
                bottom: 0, left: 0, right: 0, height: 350, 
                child: Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black.withOpacity(0.85), Colors.transparent])))
              ),

              // ─── VUES CO-HOST ───
              if (state.coHostUids.isNotEmpty)
                Positioned(
                  top: 110, right: 16,
                  child: Column(
                    children: state.coHostUids.map((uid) => Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      width: 110, height: 160,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(ThixPolicy.rMd), 
                        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1), 
                        color: ThixPolicy.inkDeep,
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))]
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(ThixPolicy.rMd - 1),
                        child: AgoraVideoView(
                          controller: VideoViewController.remote(
                            rtcEngine: notifier.engine!, canvas: VideoCanvas(uid: uid), connection: RtcConnection(channelId: widget.session.channelName), useFlutterTexture: kIsWeb,
                          ),
                        ),
                      ),
                    )).toList(),
                  ),
                ),

              // ─── BARRE SUPÉRIEURE (Host & Viewers) ───
              _buildTopBar(context, state, notifier),

              // ─── ZONE DE CHAT ───
              Positioned(
                left: 16, bottom: 90, width: MediaQuery.of(context).size.width * 0.75, height: 280,
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

              // ─── BOTTOM DOCK (Chat Input & Controls) ───
              Positioned(
                left: 0, right: 0, bottom: 0,
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Input de Chat
                        Expanded(
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
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14)
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        
                        // Boutons d'actions groupés
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _ActionDockButton(icon: state.isBeautyEnabled ? Icons.face_retouching_natural_rounded : Icons.face_rounded, active: state.isBeautyEnabled, onTap: notifier.toggleBeauty),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _ActionDockButton(icon: Icons.flip_camera_ios_rounded, onTap: notifier.switchCamera),
                                const SizedBox(width: 10),
                                _ActionDockButton(icon: state.isMuted ? Icons.mic_off_rounded : Icons.mic_rounded, isDanger: state.isMuted, onTap: notifier.toggleMute),
                                const SizedBox(width: 10),
                                _ActionDockButton(icon: state.isVideoOff ? Icons.videocam_off_rounded : Icons.videocam_rounded, isDanger: state.isVideoOff, onTap: notifier.toggleVideo),
                                const SizedBox(width: 10),
                                _ActionDockButton(icon: Icons.favorite_rounded, color: ThixPolicy.primary, onTap: notifier.triggerHeart, isPulse: true),
                              ],
                            ),
                          ],
                        )
                      ],
                    ),
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
          return Container(color: ThixPolicy.inkDeep);
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
          color: ThixPolicy.inkDeep,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(color: ThixPolicy.primary),
                const SizedBox(height: 16),
                Text("Connexion au direct en cours...", style: ThixPolicy.bodyStyle.copyWith(color: Colors.white70)),
              ],
            ),
          ),
        );

      case LiveScreenStatus.permissionDenied:
        return Container(
          color: ThixPolicy.inkDeep,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: ThixPolicy.danger.withOpacity(0.1), shape: BoxShape.circle),
                    child: const Icon(Icons.no_photography_rounded, color: ThixPolicy.danger, size: 40),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    "Autorisation caméra/micro requise\npour démarrer le direct.",
                    textAlign: TextAlign.center,
                    style: ThixPolicy.h3Style.copyWith(color: Colors.white, height: 1.4),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.primary, minimumSize: const Size(200, 48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rMd))),
                    onPressed: () => openAppSettings(),
                    child: Text('Ouvrir les réglages', style: ThixPolicy.buttonText),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => notifier.bootstrap(initialVideoEnabled: widget.isVideoEnabled, initialMicEnabled: widget.isMicEnabled),
                    child: Text('Réessayer', style: ThixPolicy.labelStyle.copyWith(color: Colors.white70)),
                  ),
                ],
              ),
            ),
          ),
        );

      case LiveScreenStatus.error:
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
                    "Erreur d'initialisation :\n${state.errorMessage ?? 'Inconnue'}",
                    textAlign: TextAlign.center,
                    style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.danger, fontWeight: ThixPolicy.bold),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rMd))),
                    onPressed: () => notifier.bootstrap(initialVideoEnabled: widget.isVideoEnabled, initialMicEnabled: widget.isMicEnabled),
                    child: Text('Réessayer', style: ThixPolicy.buttonText),
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

  Widget _buildTopBar(BuildContext context, LiveState state, LiveController notifier) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── HOST INFO (Glassmorphism) ───
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
            
            // ─── VIEWER COUNT ───
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
                      Text('${state.viewerCount}', style: ThixPolicy.labelStyle.copyWith(color: Colors.white, fontSize: 13, fontWeight: ThixPolicy.bold))
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            
            // ─── BOUTON FIN DE LIVE ROUGE ───
            GestureDetector(
              onTap: () async {
                await notifier.endBroadcast();
                if (context.mounted) Navigator.of(context).pop();
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(ThixPolicy.rFull),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: ThixPolicy.danger.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(ThixPolicy.rFull), 
                      border: Border.all(color: Colors.white.withOpacity(0.2))
                    ),
                    child: state.isEnding 
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                      : Row(
                          children: [
                            const Icon(Icons.power_settings_new_rounded, color: Colors.white, size: 14),
                            const SizedBox(width: 6),
                            Text('FIN', style: ThixPolicy.labelStyle.copyWith(color: Colors.white, fontWeight: ThixPolicy.bold, fontSize: 12)),
                          ],
                        ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} // ✅ ICI MANQUAIT L'ACCOLADE QUI FERME LA CLASSE DE BASE !

// ─── COMPOSANTS ANNEXES ───

class _ActionDockButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool active;
  final bool isDanger;
  final Color? color;
  final bool isPulse;

  const _ActionDockButton({required this.icon, required this.onTap, this.active = false, this.isDanger = false, this.color, this.isPulse = false});

  @override
  Widget build(BuildContext context) {
    final bgColor = isDanger ? ThixPolicy.danger : (active ? ThixPolicy.primary : Colors.white.withOpacity(0.15));
    final iconColor = (isDanger || active) ? Colors.white : (color ?? Colors.white);

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(ThixPolicy.rFull),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.2)),
              boxShadow: isPulse ? [BoxShadow(color: (color ?? ThixPolicy.primary).withOpacity(0.4), blurRadius: 12, spreadRadius: 2)] : null,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
        ),
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
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));
    _pos = Tween<double>(begin: 0, end: 500).animate(CurvedAnimation(parent: _c, curve: Curves.easeOut));
    _op = Tween<double>(begin: 1.0, end: 0.0).animate(CurvedAnimation(parent: _c, curve: const Interval(0.5, 1.0, curve: Curves.easeOut)));
    _sc = Tween<double>(begin: 0.6, end: 1.6).animate(CurvedAnimation(parent: _c, curve: Curves.elasticOut));
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
        bottom: 80 + _pos.value,
        right: 40 + _x + (sin(_pos.value / 40) * 30),
        child: Opacity(
          opacity: _op.value, 
          child: Transform.scale(
            scale: _sc.value, 
            child: Icon(Icons.favorite_rounded, color: widget.color, size: 28, shadows: [Shadow(color: Colors.black.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))])
          )
        ),
      ),
    );
  }
}
