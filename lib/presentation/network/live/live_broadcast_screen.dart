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
import 'package:share_plus/share_plus.dart';
import 'package:html/parser.dart' as html_parser;

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/data/models/live/live_model.dart';
import 'package:thix_id/presentation/network/live/live_controller.dart';
import 'package:thix_id/models/certification_tier.dart';
import 'package:thix_id/presentation/certification/widgets/certification_name_badge.dart';

// ============================================================================
// VALIDATEURS
// ============================================================================
class _LiveValidators {
  _LiveValidators._();

  static const int maxCommentLength = 300;
  static const int maxFloatingHearts = 8;

  static String sanitize(String? input, {int maxLength = 500}) {
    if (input == null || input.trim().isEmpty) return '';
    final doc = html_parser.parse(input);
    var sanitized = doc.body?.text ?? input;
    sanitized = sanitized
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'javascript:', caseSensitive: false), '')
        .replaceAll(RegExp(r'on\w+\s*=', caseSensitive: false), '')
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        .trim();
    return sanitized.length > maxLength ? sanitized.substring(0, maxLength) : sanitized;
  }

  static String? sanitizeUrl(String? url) {
    if (url == null || url.trim().isEmpty) return null;
    final trimmed = url.trim();
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) return null;
    return trimmed.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
  }

  static String formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
    return '$count';
  }

  static String formatDuration(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return h > 0 ? '${two(h)}:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }
}

// ============================================================================
// COMPOSANT PRINCIPAL
// ============================================================================
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
  final ScrollController _chatScrollController = ScrollController();
  final List<Widget> _floatingHearts = [];
  final Random _random = Random();
  bool _listenersAttached = false;

  // Timer de diffusion
  Timer? _durationTimer;
  Duration _broadcastDuration = Duration.zero;

  final List<Color> _heartColors = [
    ThixPolicy.danger,
    ThixPolicy.primary,
    ThixPolicy.gold,
    ThixPolicy.success,
    Colors.white,
    const Color(0xFFEC4899),
  ];

  @override
  void initState() {
    super.initState();
    _chatController.addListener(_onChatChanged);
    _startDurationTimer();
    debugPrint('[Live] Broadcast screen opened for session ${widget.session.id}');
  }

  void _startDurationTimer() {
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _broadcastDuration += const Duration(seconds: 1));
    });
  }

  void _onChatChanged() {
    if (_chatController.text.length > _LiveValidators.maxCommentLength) {
      _chatController.text = _chatController.text.substring(0, _LiveValidators.maxCommentLength);
      _chatController.selection = TextSelection.collapsed(offset: _LiveValidators.maxCommentLength);
      HapticFeedback.lightImpact();
    }
  }

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
    final safeName = _LiveValidators.sanitize(requestUserName, maxLength: 50);

    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThixPolicy.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rLg)),
        title: Row(
          children: [
            const Icon(Icons.video_call_rounded, color: ThixPolicy.primary, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Demande de participation', style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold)),
            ),
          ],
        ),
        content: Text('$safeName souhaite rejoindre le direct en vidéo.', style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textSecondary, height: 1.4)),
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
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rSm)),
              elevation: 0,
            ),
            onPressed: () {
              notifier.respondToCoHost(requestUserId, true);
              Navigator.pop(ctx);
            },
            child: const Text('Accepter'),
          ),
        ],
      ),
    );
  }

  void _spawnHeart() {
    if (!mounted) return;
    // Limiter le nombre de cœurs simultanés pour la performance
    if (_floatingHearts.length >= _LiveValidators.maxFloatingHearts) return;

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
    final raw = _chatController.text.trim();
    if (raw.isEmpty) return;

    final sanitized = _LiveValidators.sanitize(raw, maxLength: _LiveValidators.maxCommentLength);
    if (sanitized.isEmpty) return;

    HapticFeedback.selectionClick();
    ref.read(liveControllerProvider(widget.session).notifier).sendComment(sanitized);
    _chatController.clear();
    FocusScope.of(context).unfocus();
    debugPrint('[Live] Comment sent');
  }

  void _shareLive() {
    HapticFeedback.selectionClick();
    final hostName = _LiveValidators.sanitize(widget.session.hostName, maxLength: 50);
    Share.share(
      '🔴 Rejoignez le direct de $hostName sur THIX ID !\nhttps://thix.app/live/${widget.session.id}',
      subject: 'Direct THIX : $hostName',
    );
  }

  Future<void> _confirmEndBroadcast() async {
    final notifier = ref.read(liveControllerProvider(widget.session).notifier);
    if (notifier.isEnding) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThixPolicy.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rLg)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: ThixPolicy.danger.withOpacity(0.1),
                borderRadius: BorderRadius.circular(ThixPolicy.rSm),
              ),
              child: const Icon(Icons.warning_amber_rounded, color: ThixPolicy.danger, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text('Terminer le direct ?', style: ThixPolicy.titleStyle.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.danger)),
            ),
          ],
        ),
        content: Text(
          'Êtes-vous sûr de vouloir mettre fin à votre direct ?\n\nLes spectateurs seront déconnectés et le direct ne pourra pas être repris.',
          style: ThixPolicy.bodyStyle.copyWith(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Annuler', style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.danger, foregroundColor: Colors.white),
            child: const Text('Terminer'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    HapticFeedback.heavyImpact();
    await notifier.endBroadcast();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _reportComment(String userName, String text) async {
    const reasons = ['Spam', 'Contenu inapproprié', 'Harcèlement', 'Désinformation', 'Autre'];
    String? selected;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: ThixPolicy.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rLg)),
          title: Row(
            children: [
              const Icon(Icons.flag_outlined, color: ThixPolicy.warning, size: 24),
              const SizedBox(width: 8),
              Text('Signaler', style: ThixPolicy.titleStyle.copyWith(fontWeight: ThixPolicy.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Signaler le commentaire de ${_LiveValidators.sanitize(userName, maxLength: 30)}', style: ThixPolicy.bodySmallStyle),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: ThixPolicy.surfaceSoft,
                  borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                  border: Border.all(color: ThixPolicy.border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selected,
                    isExpanded: true,
                    hint: Text('Motif', style: ThixPolicy.bodySmallStyle),
                    items: reasons.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                    onChanged: (v) => setS(() => selected = v),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Annuler', style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.textSecondary))),
            ElevatedButton(
              onPressed: selected == null ? null : () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.warning, foregroundColor: Colors.white),
              child: const Text('Signaler'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && selected != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('Signalement envoyé'),
            ],
          ),
          backgroundColor: ThixPolicy.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _chatController.dispose();
    _chatScrollController.dispose();
    debugPrint('[Live] Broadcast screen disposed');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _attachListenersOnce();

    final state = ref.watch(liveControllerProvider(widget.session));
    final notifier = ref.read(liveControllerProvider(widget.session).notifier);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _confirmEndBroadcast();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        resizeToAvoidBottomInset: true,
        body: Stack(
          children: [
            Positioned.fill(child: _buildBackground(context, state, notifier)),

            if (state.status == LiveScreenStatus.ready) ...[
              Positioned(
                top: 0, left: 0, right: 0, height: 160,
                child: IgnorePointer(child: Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black.withOpacity(0.7), Colors.transparent])))),
              ),
              Positioned(
                bottom: 0, left: 0, right: 0, height: 350,
                child: IgnorePointer(child: Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black.withOpacity(0.85), Colors.transparent])))),
              ),

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

              _buildTopBar(context, state, notifier),

              Positioned(
                left: 16, bottom: 110, width: MediaQuery.of(context).size.width * 0.75, height: 280,
                child: ShaderMask(
                  shaderCallback: (Rect bounds) => const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.white, Colors.white], stops: [0.0, 0.15, 1.0]).createShader(bounds),
                  blendMode: BlendMode.dstIn,
                  child: ListView.builder(
                    controller: _chatScrollController,
                    reverse: true,
                    physics: const BouncingScrollPhysics(),
                    itemCount: state.comments.length,
                    itemBuilder: (context, index) {
                      final comment = state.comments[state.comments.length - 1 - index];
                      return _buildCommentBubble(comment);
                    },
                  ),
                ),
              ),

              Positioned(
                left: 0, right: 0, bottom: 0,
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
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
                                  maxLength: _LiveValidators.maxCommentLength,
                                  buildCounter: (_, {required currentLength, required isFocused, maxLength}) =>
                                      currentLength > maxLength! * 0.8
                                          ? Padding(
                                              padding: const EdgeInsets.only(right: 12),
                                              child: Text('$currentLength/$maxLength', style: ThixPolicy.microStyle.copyWith(color: currentLength >= maxLength! ? ThixPolicy.danger : Colors.white54)),
                                            )
                                          : null,
                                  decoration: InputDecoration(
                                    hintText: 'Commenter...',
                                    hintStyle: ThixPolicy.bodyStyle.copyWith(color: Colors.white54),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                    counterText: '',
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _ActionDockButton(
                              icon: state.isBeautyEnabled ? Icons.face_retouching_natural_rounded : Icons.face_rounded,
                              active: state.isBeautyEnabled,
                              onTap: notifier.toggleBeauty,
                              tooltip: state.isBeautyEnabled ? 'Beauté activée' : 'Beauté',
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _ActionDockButton(icon: Icons.flip_camera_ios_rounded, onTap: notifier.switchCamera, tooltip: 'Changer caméra'),
                                const SizedBox(width: 10),
                                _ActionDockButton(icon: state.isMuted ? Icons.mic_off_rounded : Icons.mic_rounded, isDanger: state.isMuted, onTap: notifier.toggleMute, tooltip: state.isMuted ? 'Activer micro' : 'Couper micro'),
                                const SizedBox(width: 10),
                                _ActionDockButton(icon: state.isVideoOff ? Icons.videocam_off_rounded : Icons.videocam_rounded, isDanger: state.isVideoOff, onTap: notifier.toggleVideo, tooltip: state.isVideoOff ? 'Activer vidéo' : 'Couper vidéo'),
                                const SizedBox(width: 10),
                                _ActionDockButton(icon: Icons.favorite_rounded, color: ThixPolicy.primary, onTap: notifier.triggerHeart, isPulse: true, tooltip: 'Envoyer cœur'),
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

  Widget _buildCommentBubble(dynamic comment) {
    final userName = _LiveValidators.sanitize(comment.userName, maxLength: 50);
    final text = _LiveValidators.sanitize(comment.text, maxLength: _LiveValidators.maxCommentLength);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: GestureDetector(
          onLongPress: () => _reportComment(userName, text),
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
                      TextSpan(text: '$userName  ', style: ThixPolicy.labelStyle.copyWith(color: Colors.white70, fontWeight: ThixPolicy.bold)),
                      TextSpan(text: text, style: ThixPolicy.bodyStyle.copyWith(color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ),
          ),
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
          child: AgoraVideoView(
            controller: VideoViewController(
              rtcEngine: notifier.engine!,
              canvas: const VideoCanvas(uid: 0, renderMode: RenderModeType.renderModeHidden),
              useFlutterTexture: kIsWeb,
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
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: ThixPolicy.primary.withOpacity(0.1), shape: BoxShape.circle),
                  child: const CircularProgressIndicator(color: ThixPolicy.primary),
                ),
                const SizedBox(height: 16),
                Text("Connexion au direct en cours...", style: ThixPolicy.bodyStyle.copyWith(color: Colors.white70)),
              ],
            ),
          ),
        );

      case LiveScreenStatus.permissionDenied:
        return _buildPermissionDeniedState(notifier);

      case LiveScreenStatus.error:
        return _buildErrorState(state, notifier);
    }
  }

  Widget _buildPermissionDeniedState(LiveController notifier) {
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
                child: const Icon(Icons.no_photography_rounded, color: ThixPolicy.danger, size: 48),
              ),
              const SizedBox(height: 24),
              Text(
                "Autorisation caméra/micro requise",
                textAlign: TextAlign.center,
                style: ThixPolicy.h3Style.copyWith(color: Colors.white, fontWeight: ThixPolicy.bold),
              ),
              const SizedBox(height: 8),
              Text(
                "Pour démarrer le direct, THIX ID a besoin d'accéder à votre caméra et votre microphone.",
                textAlign: TextAlign.center,
                style: ThixPolicy.bodyStyle.copyWith(color: Colors.white70, height: 1.4),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: ThixPolicy.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(200, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rMd)),
                ),
                icon: const Icon(Icons.settings_rounded),
                label: const Text('Ouvrir les réglages'),
                onPressed: () => openAppSettings(),
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
  }

  Widget _buildErrorState(LiveState state, LiveController notifier) {
    final errorMsg = _LiveValidators.sanitize(state.errorMessage ?? 'Erreur inconnue', maxLength: 200);
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
                child: const Icon(Icons.error_outline_rounded, color: ThixPolicy.danger, size: 48),
              ),
              const SizedBox(height: 24),
              Text("Erreur d'initialisation", style: ThixPolicy.h3Style.copyWith(color: Colors.white, fontWeight: ThixPolicy.bold)),
              const SizedBox(height: 8),
              Text(errorMsg, textAlign: TextAlign.center, style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.danger)),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: ThixPolicy.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rMd)),
                ),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Réessayer'),
                onPressed: () => notifier.bootstrap(initialVideoEnabled: widget.isVideoEnabled, initialMicEnabled: widget.isMicEnabled),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMinimalTopBar(BuildContext context, LiveController notifier) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            const Spacer(),
            Semantics(
              button: true,
              label: 'Fermer',
              child: GestureDetector(
                onTap: _confirmEndBroadcast,
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, LiveState state, LiveController notifier) {
    final hostName = _LiveValidators.sanitize(widget.session.hostName, maxLength: 50);
    final avatarUrl = _LiveValidators.sanitizeUrl(widget.session.hostAvatarUrl);

    // Parsing certification (si disponible dans la session)
    final tier = CertificationTierX.parse(widget.session.certificationTier);
    final status = CertificationStatusX.parse(widget.session.certificationStatus);
    final isCertified = status == CertificationStatus.approved || status == CertificationStatus.generated;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Badge Live + Host
            ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(4, 4, 16, 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: ThixPolicy.danger, width: 2),
                        ),
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: ThixPolicy.primary,
                          backgroundImage: avatarUrl != null ? CachedNetworkImageProvider(avatarUrl) : null,
                          child: avatarUrl == null ? const Icon(Icons.person, size: 20, color: Colors.white) : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(hostName, style: ThixPolicy.labelStyle.copyWith(color: Colors.white, fontSize: 13, fontWeight: ThixPolicy.bold)),
                              if (isCertified)
                                Padding(
                                  padding: const EdgeInsets.only(left: 4),
                                  child: CertificationNameBadge(tier: tier, status: status, showLabel: false, iconSize: 12),
                                ),
                            ],
                          ),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: ThixPolicy.danger, borderRadius: BorderRadius.circular(4)),
                                child: const Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _LiveValidators.formatDuration(_broadcastDuration),
                                style: ThixPolicy.microStyle.copyWith(color: Colors.white70, fontWeight: ThixPolicy.semiBold, letterSpacing: 0.3),
                              ),
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

            // Viewers count
            Semantics(
              label: '${state.viewerCount} spectateurs',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(ThixPolicy.rFull),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(ThixPolicy.rFull),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.visibility_rounded, color: Colors.white, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          _LiveValidators.formatCount(state.viewerCount),
                          style: ThixPolicy.labelStyle.copyWith(color: Colors.white, fontSize: 13, fontWeight: ThixPolicy.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Share button
            Semantics(
              button: true,
              label: 'Partager le direct',
              child: GestureDetector(
                onTap: _shareLive,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(ThixPolicy.rFull),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: const Icon(Icons.share_rounded, color: Colors.white, size: 18),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // End button
            Semantics(
              button: true,
              label: 'Terminer le direct',
              child: GestureDetector(
                onTap: _confirmEndBroadcast,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(ThixPolicy.rFull),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: ThixPolicy.danger.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(ThixPolicy.rFull),
                        border: Border.all(color: Colors.white.withOpacity(0.2)),
                      ),
                      child: state.isEnding
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Row(
                              mainAxisSize: MainAxisSize.min,
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
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// BOUTON D'ACTION AVEC TOOLTIP
// ============================================================================
class _ActionDockButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool active;
  final bool isDanger;
  final Color? color;
  final bool isPulse;
  final String? tooltip;

  const _ActionDockButton({
    required this.icon,
    required this.onTap,
    this.active = false,
    this.isDanger = false,
    this.color,
    this.isPulse = false,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isDanger ? ThixPolicy.danger : (active ? ThixPolicy.primary : Colors.white.withOpacity(0.15));
    final iconColor = (isDanger || active) ? Colors.white : (color ?? Colors.white);

    return Semantics(
      button: true,
      label: tooltip ?? '',
      child: Tooltip(
        message: tooltip ?? '',
        child: GestureDetector(
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
        ),
      ),
    );
  }
}

// ============================================================================
// CŒUR ANIMÉ (performances optimisées)
// ============================================================================
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
    _c.forward().then((_) {
      if (mounted) widget.onComplete();
    });
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
            child: Icon(
              Icons.favorite_rounded,
              color: widget.color,
              size: 28,
              shadows: [Shadow(color: Colors.black.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))],
            ),
          ),
        ),
      ),
    );
  }
}
