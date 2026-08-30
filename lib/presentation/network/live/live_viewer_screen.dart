// lib/presentation/network/live/live_viewer_screen.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:html/parser.dart' as html_parser;

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/data/models/live/live_model.dart';
import 'package:thix_id/models/certification_tier.dart';
import 'package:thix_id/presentation/certification/widgets/certification_name_badge.dart';
import 'live_viewer_controller.dart';

// ============================================================================
// VALIDATEURS
// ============================================================================
class _ViewerScreenValidators {
  _ViewerScreenValidators._();

  static const int maxCommentLength = 300;

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
}

// ============================================================================
// COMPOSANT PRINCIPAL
// ============================================================================
class LiveViewerScreen extends ConsumerStatefulWidget {
  final LiveSession session;
  const LiveViewerScreen({super.key, required this.session});

  @override
  ConsumerState<LiveViewerScreen> createState() => _LiveViewerScreenState();
}

class _LiveViewerScreenState extends ConsumerState<LiveViewerScreen> {
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _chatController.addListener(_onChatChanged);
    debugPrint('[LiveViewer] 🎬 Screen opened for session ${widget.session.id}');
  }

  void _onChatChanged() {
    if (_chatController.text.length > _ViewerScreenValidators.maxCommentLength) {
      _chatController.text = _chatController.text.substring(0, _ViewerScreenValidators.maxCommentLength);
      _chatController.selection = TextSelection.collapsed(offset: _ViewerScreenValidators.maxCommentLength);
      HapticFeedback.lightImpact();
    }
  }

  void _sendComment() {
    final raw = _chatController.text.trim();
    if (raw.isEmpty) return;

    final sanitized = _ViewerScreenValidators.sanitize(raw, maxLength: _ViewerScreenValidators.maxCommentLength);
    if (sanitized.isEmpty) return;

    HapticFeedback.selectionClick();
    ref.read(liveViewerControllerProvider(widget.session).notifier).sendComment(sanitized);
    _chatController.clear();
    FocusScope.of(context).unfocus();
    debugPrint('[LiveViewer] 💬 Comment sent');
  }

  void _triggerHeart() {
    HapticFeedback.lightImpact();
    ref.read(liveViewerControllerProvider(widget.session).notifier).triggerHeart();
  }

  void _shareLive() {
    HapticFeedback.selectionClick();
    final hostName = _ViewerScreenValidators.sanitize(widget.session.hostName, maxLength: 50);
    Share.share(
      '🔴 Rejoignez le direct de $hostName sur THIX ID !\nhttps://thix.app/live/${widget.session.id}',
      subject: 'Direct THIX : $hostName',
    );
  }

  Future<void> _confirmLeave() async {
    final notifier = ref.read(liveViewerControllerProvider(widget.session).notifier);
    if (notifier.isLeaving) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThixPolicy.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rLg)),
        title: Row(
          children: [
            const Icon(Icons.exit_to_app_rounded, color: ThixPolicy.warning, size: 24),
            const SizedBox(width: 8),
            Expanded(child: Text('Quitter le direct ?', style: ThixPolicy.titleStyle.copyWith(fontWeight: ThixPolicy.bold))),
          ],
        ),
        content: Text('Êtes-vous sûr de vouloir quitter ce direct ?', style: ThixPolicy.bodyStyle.copyWith(height: 1.4)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Rester', style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.danger, foregroundColor: Colors.white),
            child: const Text('Quitter'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    HapticFeedback.mediumImpact();
    await notifier.leaveLive();
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
              Text('Signaler le commentaire de ${_ViewerScreenValidators.sanitize(userName, maxLength: 30)}', style: ThixPolicy.bodySmallStyle),
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
    _chatController.dispose();
    _chatScrollController.dispose();
    debugPrint('[LiveViewer] 👋 Screen disposed');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(liveViewerControllerProvider(widget.session));
    final notifier = ref.read(liveViewerControllerProvider(widget.session).notifier);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _confirmLeave();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Positioned.fill(child: _buildBackground(state, notifier)),

            if (state.status == ViewerStatus.ready) ...[
              // Gradients avec IgnorePointer pour ne pas bloquer les taps
              Positioned(
                top: 0, left: 0, right: 0, height: 140,
                child: IgnorePointer(child: Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black.withOpacity(0.7), Colors.transparent])))),
              ),
              Positioned(
                bottom: 0, left: 0, right: 0, height: 280,
                child: IgnorePointer(child: Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black.withOpacity(0.8), Colors.transparent])))),
              ),

              _buildTopBar(context, state),

              // Chat
              Positioned(
                left: 16, bottom: 110, width: MediaQuery.of(context).size.width * 0.75, height: 240,
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

              // Bottom dock : chat + bouton cœur
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
                          child: _buildChatInput(),
                        ),
                        const SizedBox(width: 12),
                        _buildHeartButton(),
                      ],
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

  Widget _buildCommentBubble(dynamic comment) {
    final userName = _ViewerScreenValidators.sanitize(comment.userName, maxLength: 50);
    final text = _ViewerScreenValidators.sanitize(comment.text, maxLength: _ViewerScreenValidators.maxCommentLength);

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

  Widget _buildChatInput() {
    final currentLength = _chatController.text.length;
    final maxLength = _ViewerScreenValidators.maxCommentLength;
    final showCounter = currentLength > maxLength * 0.8;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
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
                maxLength: maxLength,
                buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                decoration: InputDecoration(
                  hintText: 'Commenter...',
                  hintStyle: ThixPolicy.bodyStyle.copyWith(color: Colors.white54),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  counterText: '',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.send_rounded, color: Colors.white70, size: 20),
                    onPressed: _sendComment,
                  ),
                ),
              ),
            ),
          ),
        ),
        if (showCounter)
          Padding(
            padding: const EdgeInsets.only(left: 20, top: 4),
            child: Text(
              '$currentLength/$maxLength',
              style: ThixPolicy.microStyle.copyWith(
                color: currentLength >= maxLength ? ThixPolicy.danger : Colors.white54,
                fontWeight: ThixPolicy.semiBold,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildHeartButton() {
    return Semantics(
      button: true,
      label: 'Envoyer un cœur',
      child: GestureDetector(
        onTap: _triggerHeart,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(ThixPolicy.rFull),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [ThixPolicy.danger, Color(0xFFEC4899)]),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.2)),
                boxShadow: [BoxShadow(color: ThixPolicy.danger.withOpacity(0.4), blurRadius: 12, spreadRadius: 2)],
              ),
              child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 22),
            ),
          ),
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
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), shape: BoxShape.circle),
                    child: const Icon(Icons.videocam_off_rounded, color: Colors.white24, size: 60),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Caméra de l'hôte désactivée",
                    style: ThixPolicy.bodyStyle.copyWith(color: Colors.white54),
                  ),
                ],
              ),
            ),
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
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: ThixPolicy.primary.withOpacity(0.1), shape: BoxShape.circle),
                  child: const CircularProgressIndicator(color: ThixPolicy.primary),
                ),
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
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), shape: BoxShape.circle),
                    child: const Icon(Icons.stop_circle_outlined, color: Colors.white54, size: 64),
                  ),
                  const SizedBox(height: 24),
                  Text("Le direct est terminé", style: ThixPolicy.h3Style.copyWith(color: Colors.white, fontWeight: ThixPolicy.bold)),
                  const SizedBox(height: 8),
                  Text(
                    "L'hôte a mis fin à la diffusion.",
                    style: ThixPolicy.bodyStyle.copyWith(color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ThixPolicy.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rFull)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: const Text('Retour'),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
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
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(color: ThixPolicy.danger.withOpacity(0.1), shape: BoxShape.circle),
                    child: const Icon(Icons.error_outline_rounded, color: ThixPolicy.danger, size: 56),
                  ),
                  const SizedBox(height: 24),
                  Text("Erreur de connexion", style: ThixPolicy.h3Style.copyWith(color: Colors.white, fontWeight: ThixPolicy.bold)),
                  const SizedBox(height: 8),
                  Text(
                    _ViewerScreenValidators.sanitize(state.errorMessage ?? "Erreur inconnue", maxLength: 200),
                    textAlign: TextAlign.center,
                    style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.danger),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ThixPolicy.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rFull)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Réessayer'),
                    onPressed: () => ref.read(liveViewerControllerProvider(widget.session).notifier).retry(),
                  ),
                ],
              ),
            ),
          ),
        );
    }
  }

  Widget _buildTopBar(BuildContext context, LiveViewerState state) {
    final hostName = _ViewerScreenValidators.sanitize(widget.session.hostName, maxLength: 50);
    final avatarUrl = _ViewerScreenValidators.sanitizeUrl(widget.session.hostAvatarUrl);

    // Parsing certification
    final tier = CertificationTierX.parse(widget.session.certificationTier);
    final status = CertificationStatusX.parse(widget.session.certificationStatus);
    final isCertified = status == CertificationStatus.approved || status == CertificationStatus.generated;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
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

            // Viewers count formaté
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
                          _ViewerScreenValidators.formatCount(state.viewerCount),
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

            // Close button
            Semantics(
              button: true,
              label: 'Quitter le direct',
              child: GestureDetector(
                onTap: _confirmLeave,
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
}
