import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/data/models/live/audio_space_model.dart';
import 'package:thix_id/features/auth/presentation/providers/auth_controller.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/presentation/network/live/audio_space_controller.dart';

const Duration _kActionThrottle = Duration(milliseconds: 400);
const Duration _kChatThrottle = Duration(milliseconds: 600);
const int _kChatMaxLength = 300;
const List<String> _kReactions = ['❤️', '👏', '🔥', '😂', '🙌'];

class _SpaceSanitizer {
  _SpaceSanitizer._();
  static String chat(String? input) {
    if (input == null) return '';
    var s = input
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '')
        .trim();
    if (s.length > _kChatMaxLength) s = s.substring(0, _kChatMaxLength);
    return s;
  }
}

class AudioSpaceRoomScreen extends ConsumerStatefulWidget {
  final AudioSpace space;
  const AudioSpaceRoomScreen({super.key, required this.space});

  @override
  ConsumerState<AudioSpaceRoomScreen> createState() =>
      _AudioSpaceRoomScreenState();
}

class _AudioSpaceRoomScreenState extends ConsumerState<AudioSpaceRoomScreen> {
  final _chatCtrl = TextEditingController();
  final _chatScroll = ScrollController();
  bool _started = false;
  DateTime? _lastAction;
  DateTime? _lastChat;
  int _reactionBurst = 0;
  String _lastReaction = '';

  String _tx(AppLocalizations l10n, String key, String fallback) {
    final v = l10n.t(key);
    if (v.isEmpty || v == key) return fallback;
    return v;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final user = ref.read(authControllerProvider).value;
    Future.microtask(() {
      ref.read(audioSpaceControllerProvider(widget.space).notifier).bootstrap(
            displayName: user?.displayName ?? 'Membre THIX',
            avatarUrl: user?.photoUrl,
          );
    });
  }

  @override
  void dispose() {
    _chatCtrl.dispose();
    _chatScroll.dispose();
    super.dispose();
  }

  bool _throttleAction() {
    final now = DateTime.now();
    if (_lastAction != null && now.difference(_lastAction!) < _kActionThrottle) {
      return false;
    }
    _lastAction = now;
    return true;
  }

  bool _throttleChat() {
    final now = DateTime.now();
    if (_lastChat != null && now.difference(_lastChat!) < _kChatThrottle) {
      return false;
    }
    _lastChat = now;
    return true;
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? ThixPolicy.danger : ThixPolicy.domainMedia,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ));
  }

  String _roleLabel(AppLocalizations l10n, AudioSpaceRole r) {
    switch (r) {
      case AudioSpaceRole.host:
        return _tx(l10n, 'audio_space_host', 'Hôte');
      case AudioSpaceRole.cohost:
        return _tx(l10n, 'audio_space_cohost', 'Co-hôte');
      case AudioSpaceRole.speaker:
        return _tx(l10n, 'audio_space_speaker', 'Intervenant');
      case AudioSpaceRole.listener:
        return _tx(l10n, 'audio_space_listener', 'Auditeur');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(audioSpaceControllerProvider(widget.space));
    final ctrl = ref.read(audioSpaceControllerProvider(widget.space).notifier);
    final liveCount = state.participants.length;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _leave(ctrl);
      },
      child: Scaffold(
        backgroundColor: ThixPolicy.tint,
        appBar: AppBar(
          backgroundColor: ThixPolicy.card,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
            tooltip: _tx(l10n, 'audio_space_leave', 'Quitter'),
            onPressed: () => _leave(ctrl),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.space.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ThixPolicy.h2Style.copyWith(fontSize: 16),
              ),
              Text(
                '${widget.space.topic} · $liveCount ${_tx(l10n, 'audio_space_people', 'personnes')}',
                style: TextStyle(fontSize: 12, color: ThixPolicy.textSecondary),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.share_rounded),
              tooltip: _tx(l10n, 'audio_space_share', 'Partager'),
              onPressed: () => _shareSpace(l10n),
            ),
            if (ctrl.isHost)
              TextButton(
                onPressed: () => _confirmEnd(l10n, ctrl),
                child: Text(
                  _tx(l10n, 'audio_space_end', 'Terminer'),
                  style: const TextStyle(color: ThixPolicy.danger),
                ),
              ),
          ],
        ),
        body: _buildBody(l10n, state, ctrl),
      ),
    );
  }

  Widget _buildBody(
    AppLocalizations l10n,
    AudioSpaceState state,
    AudioSpaceController ctrl,
  ) {
    switch (state.status) {
      case AudioSpaceScreenStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case AudioSpaceScreenStatus.permissionDenied:
        return _statusPane(
          _tx(l10n, 'audio_space_mic_denied', 'Micro refusé. Active-le dans les réglages.'),
          Icons.mic_off_rounded,
        );
      case AudioSpaceScreenStatus.banned:
        return _statusPane(
          _tx(l10n, 'audio_space_banned', 'Tu as été exclu de ce salon.'),
          Icons.block_rounded,
        );
      case AudioSpaceScreenStatus.error:
        return _statusPane(
          state.errorMessage ?? _tx(l10n, 'audio_space_error', 'Impossible de rejoindre le salon.'),
          Icons.error_outline,
        );
      case AudioSpaceScreenStatus.ready:
        final raised = state.participants.where((p) => p.handRaised).length;
        return Stack(
          children: [
            Column(
              children: [
                if (widget.space.recordingEnabled)
                  Container(
                    width: double.infinity,
                    color: ThixPolicy.warning.withValues(alpha: 0.15),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      _tx(l10n, 'audio_space_recording_notice', 'Ce salon est enregistré.'),
                      style: TextStyle(fontSize: 12, color: ThixPolicy.warning),
                    ),
                  ),
                if (ctrl.isHost && raised > 0)
                  Material(
                    color: ThixPolicy.domainMedia.withValues(alpha: 0.1),
                    child: InkWell(
                      onTap: () => _requestsSheet(l10n, state, ctrl),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        child: Row(
                          children: [
                            Icon(Icons.back_hand_rounded, color: ThixPolicy.domainMedia, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '$raised ${_tx(l10n, 'audio_space_requests', 'demandes de parole')}',
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                            Text(_tx(l10n, 'audio_space_invite', 'Gérer'),
                                style: TextStyle(color: ThixPolicy.domainMedia)),
                          ],
                        ),
                      ),
                    ),
                  ),
                Expanded(child: _speakersGrid(l10n, state, ctrl)),
                _listenersRow(l10n, state),
                _chatList(l10n, state),
                _reactionsBar(l10n, ctrl),
                _composer(l10n, ctrl),
                _controls(l10n, state, ctrl),
              ],
            ),
            if (_reactionBurst > 0)
              Positioned(
                right: 24,
                bottom: 160,
                child: _ReactionBurst(
                  key: ValueKey(_reactionBurst),
                  emoji: _lastReaction,
                ),
              ),
          ],
        );
    }
  }

  Widget _statusPane(String text, IconData icon) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: ThixPolicy.textSecondary),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center, style: ThixPolicy.bodyStyle),
          ],
        ),
      ),
    );
  }

  Widget _speakersGrid(
    AppLocalizations l10n,
    AudioSpaceState state,
    AudioSpaceController ctrl,
  ) {
    final speakers =
        state.participants.where((p) => p.role != AudioSpaceRole.listener).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      children: [
        Text(
          _tx(l10n, 'audio_space_speakers', 'Intervenants'),
          style: ThixPolicy.h2Style.copyWith(fontSize: 14),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            for (final p in speakers)
              _person(
                l10n,
                p,
                ctrl,
                canModerate: ctrl.isHost || state.myRole == AudioSpaceRole.cohost,
              ),
          ],
        ),
      ],
    );
  }

  Widget _person(
    AppLocalizations l10n,
    AudioSpaceParticipant p,
    AudioSpaceController ctrl, {
    required bool canModerate,
  }) {
    return Semantics(
      button: true,
      label: '${p.displayName}, ${_roleLabel(l10n, p.role)}',
      child: GestureDetector(
        onTap: canModerate && p.role != AudioSpaceRole.host
            ? () => _moderationSheet(l10n, p, ctrl)
            : null,
        onLongPress: canModerate && p.role != AudioSpaceRole.host
            ? () => _moderationSheet(l10n, p, ctrl)
            : null,
        child: SizedBox(
          width: 88,
          child: Column(
            children: [
              Stack(
                children: [
                  _avatar(p.avatarUrl, 64),
                  if (!p.isMuted)
                    const Positioned(right: 0, bottom: 0, child: _SpeakingBadge()),
                  if (p.isMuted)
                    const Positioned(
                      right: 0,
                      bottom: 0,
                      child: CircleAvatar(
                        radius: 10,
                        backgroundColor: Colors.black54,
                        child: Icon(Icons.mic_off, size: 12, color: Colors.white),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                p.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              Text(
                _roleLabel(l10n, p.role),
                style: TextStyle(fontSize: 10, color: ThixPolicy.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _listenersRow(AppLocalizations l10n, AudioSpaceState state) {
    final listeners =
        state.participants.where((p) => p.role == AudioSpaceRole.listener).toList();
    if (listeners.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Text(
            '${_tx(l10n, 'audio_space_listeners', 'Auditeurs')} · ${listeners.length}',
            style: TextStyle(fontSize: 12, color: ThixPolicy.textSecondary),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SizedBox(
              height: 28,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final l in listeners.take(10))
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: _avatar(l.avatarUrl, 28),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatar(String? url, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: ThixPolicy.surfaceSoft,
        border: Border.all(color: ThixPolicy.border),
      ),
      child: ClipOval(
        child: (url != null && url.isNotEmpty)
            ? CachedNetworkImage(imageUrl: url, fit: BoxFit.cover)
            : Icon(Icons.person, size: size * 0.5, color: ThixPolicy.textSecondary),
      ),
    );
  }

  Widget _chatList(AppLocalizations l10n, AudioSpaceState state) {
    if (state.messages.isEmpty) {
      return SizedBox(
        height: 48,
        child: Center(
          child: Text(
            _tx(l10n, 'audio_space_chat_empty', 'Le chat du salon apparaît ici pour tout le monde.'),
            style: TextStyle(fontSize: 12, color: ThixPolicy.textMuted),
          ),
        ),
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScroll.hasClients) {
        _chatScroll.jumpTo(_chatScroll.position.maxScrollExtent);
      }
    });
    return SizedBox(
      height: 140,
      child: ListView.builder(
        controller: _chatScroll,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: state.messages.length,
        itemBuilder: (_, i) {
          final m = state.messages[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text.rich(TextSpan(children: [
              TextSpan(
                text: '${m.displayName} ',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              TextSpan(text: m.body, style: const TextStyle(fontSize: 13)),
            ])),
          );
        },
      ),
    );
  }

  Widget _composer(AppLocalizations l10n, AudioSpaceController ctrl) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _chatCtrl,
              maxLength: _kChatMaxLength,
              inputFormatters: [
                FilteringTextInputFormatter.deny(RegExp(r'[<>]')),
              ],
              decoration: InputDecoration(
                counterText: '',
                hintText: _tx(l10n, 'audio_space_chat_hint', 'Message du salon'),
                filled: true,
                fillColor: ThixPolicy.card,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onSubmitted: (_) => _sendChat(l10n, ctrl),
            ),
          ),
          IconButton(
            tooltip: _tx(l10n, 'audio_space_send', 'Envoyer'),
            onPressed: () => _sendChat(l10n, ctrl),
            icon: Icon(Icons.send_rounded, color: ThixPolicy.domainMedia),
          ),
        ],
      ),
    );
  }

  void _sendChat(AppLocalizations l10n, AudioSpaceController ctrl) {
    if (!_throttleChat()) return;
    final clean = _SpaceSanitizer.chat(_chatCtrl.text);
    if (clean.isEmpty) return;
    final user = ref.read(authControllerProvider).value;
    HapticFeedback.lightImpact();
    ctrl.sendChat(clean, user?.displayName ?? 'Membre');
    _chatCtrl.clear();
  }

  Widget _reactionsBar(AppLocalizations l10n, AudioSpaceController ctrl) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (final e in _kReactions)
            GestureDetector(
              onTap: () {
                if (!_throttleChat()) return;
                HapticFeedback.lightImpact();
                final user = ref.read(authControllerProvider).value;
                ctrl.sendChat(e, user?.displayName ?? 'Membre');
                setState(() {
                  _lastReaction = e;
                  _reactionBurst++;
                });
              },
              child: Text(e, style: const TextStyle(fontSize: 20)),
            ),
        ],
      ),
    );
  }

  Widget _controls(
    AppLocalizations l10n,
    AudioSpaceState state,
    AudioSpaceController ctrl,
  ) {
    final raised = state.participants.where((p) => p.handRaised).length;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _roundBtn(
              icon: state.isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
              color: state.isMuted ? ThixPolicy.textSecondary : ThixPolicy.domainMedia,
              label: state.isMuted
                  ? _tx(l10n, 'audio_space_muted', 'Muet')
                  : _tx(l10n, 'audio_space_live_mic', 'Micro'),
              onTap: ctrl.canSpeak || ctrl.isHost
                  ? () {
                      if (!_throttleAction()) return;
                      HapticFeedback.selectionClick();
                      ctrl.toggleMute();
                    }
                  : null,
            ),
            if (ctrl.isHost) ...[
              _roundBtn(
                icon: Icons.volume_off_rounded,
                color: ThixPolicy.textSecondary,
                label: _tx(l10n, 'audio_space_mute_all', 'Mute tous'),
                onTap: () {
                  if (!_throttleAction()) return;
                  for (final p in state.participants) {
                    if (p.role == AudioSpaceRole.host) continue;
                    if (p.role == AudioSpaceRole.listener) continue;
                    ctrl.demote(p);
                  }
                  _snack(_tx(l10n, 'audio_space_muted_all', 'Intervenants coupés'));
                },
              ),
              _roundBtn(
                icon: Icons.back_hand_rounded,
                color: ThixPolicy.domainMedia,
                label: '${_tx(l10n, 'audio_space_requests', 'Demandes')}${raised > 0 ? ' ($raised)' : ''}',
                onTap: () => _requestsSheet(l10n, state, ctrl),
              ),
            ],
            if (!ctrl.isHost && state.myRole == AudioSpaceRole.listener)
              _roundBtn(
                icon: state.handRaised
                    ? Icons.back_hand_rounded
                    : Icons.back_hand_outlined,
                color: ThixPolicy.domainMedia,
                label: _tx(l10n, 'audio_space_request', 'Parler'),
                onTap: () {
                  if (!_throttleAction()) return;
                  HapticFeedback.selectionClick();
                  ctrl.toggleHand();
                },
              ),
            _roundBtn(
              icon: Icons.logout_rounded,
              color: ThixPolicy.danger,
              label: _tx(l10n, 'audio_space_leave', 'Quitter'),
              onTap: () => _leave(ctrl),
            ),
          ],
        ),
      ),
    );
  }

  Widget _roundBtn({
    required IconData icon,
    required Color color,
    required String label,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: color.withValues(alpha: 0.12),
            child: Icon(icon, color: onTap == null ? color.withValues(alpha: 0.35) : color),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 11, color: ThixPolicy.textSecondary)),
        ],
      ),
    );
  }

  Future<void> _requestsSheet(
    AppLocalizations l10n,
    AudioSpaceState state,
    AudioSpaceController ctrl,
  ) async {
    final raised = state.participants.where((p) => p.handRaised).toList();
    await showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _tx(l10n, 'audio_space_requests', 'Demandes de parole'),
                style: ThixPolicy.h2Style.copyWith(fontSize: 16),
              ),
              const SizedBox(height: 8),
              if (raised.isEmpty)
                Text(_tx(l10n, 'audio_space_no_requests', 'Aucune demande pour le moment.')),
              for (final p in raised)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: _avatar(p.avatarUrl, 36),
                  title: Text(p.displayName),
                  trailing: TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      if (!_throttleAction()) return;
                      ctrl.promote(p);
                      _snack(_tx(l10n, 'audio_space_invited', 'Invité à parler'));
                    },
                    child: Text(_tx(l10n, 'audio_space_invite', 'Accepter')),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _moderationSheet(
    AppLocalizations l10n,
    AudioSpaceParticipant p,
    AudioSpaceController ctrl,
  ) async {
    await showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(p.displayName),
              subtitle: Text(_roleLabel(l10n, p.role)),
            ),
            if (p.role == AudioSpaceRole.listener)
              ListTile(
                leading: const Icon(Icons.mic),
                title: Text(_tx(l10n, 'audio_space_invite', 'Inviter à parler')),
                onTap: () {
                  Navigator.pop(context);
                  if (!_throttleAction()) return;
                  ctrl.promote(p);
                  _snack(_tx(l10n, 'audio_space_invited', 'Invité à parler'));
                },
              ),
            if (p.role == AudioSpaceRole.speaker || p.role == AudioSpaceRole.cohost)
              ListTile(
                leading: const Icon(Icons.hearing_disabled),
                title: Text(_tx(l10n, 'audio_space_remove_speaker', 'Retirer le micro')),
                onTap: () {
                  Navigator.pop(context);
                  if (!_throttleAction()) return;
                  ctrl.demote(p);
                  _snack(_tx(l10n, 'audio_space_removed', 'Micro retiré')),
                },
              ),
            ListTile(
              leading: const Icon(Icons.block, color: ThixPolicy.danger),
              title: Text(_tx(l10n, 'audio_space_kick', 'Expulser')),
              onTap: () {
                Navigator.pop(context);
                _confirmKick(l10n, p, ctrl);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmKick(
    AppLocalizations l10n,
    AudioSpaceParticipant p,
    AudioSpaceController ctrl,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_tx(l10n, 'audio_space_kick_confirm_title', 'Expulser ?')),
        content: Text(
          _tx(l10n, 'audio_space_kick_confirm_message', 'Retirer ${p.displayName} du salon ?'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(_tx(l10n, 'audio_space_cancel', 'Annuler')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              _tx(l10n, 'audio_space_kick', 'Expulser'),
              style: const TextStyle(color: ThixPolicy.danger),
            ),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      HapticFeedback.mediumImpact();
      ctrl.kick(p);
      _snack(_tx(l10n, 'audio_space_kicked', 'Expulsé'));
    }
  }

  Future<void> _confirmEnd(AppLocalizations l10n, AudioSpaceController ctrl) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_tx(l10n, 'audio_space_end_confirm_title', 'Terminer le salon ?')),
        content: Text(
          _tx(l10n, 'audio_space_end_confirm_message', 'Tous les participants seront déconnectés.'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(_tx(l10n, 'audio_space_cancel', 'Annuler')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              _tx(l10n, 'audio_space_end', 'Terminer'),
              style: const TextStyle(color: ThixPolicy.danger),
            ),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      HapticFeedback.mediumImpact();
      await ctrl.endSpace();
      if (mounted) Navigator.pop(context);
    }
  }

  void _shareSpace(AppLocalizations l10n) {
    if (!_throttleAction()) return;
    HapticFeedback.lightImpact();
    final link = 'https://thix.id/live/audio/${widget.space.id}';
    Clipboard.setData(ClipboardData(text: link));
    _snack(_tx(l10n, 'audio_space_link_copied', 'Lien copié'));
  }

  Future<void> _leave(AudioSpaceController ctrl) async {
    if (!_throttleAction()) return;
    if (ctrl.isHost) {
      await ctrl.endSpace();
    } else {
      await ctrl.leave();
    }
    if (mounted) Navigator.pop(context);
  }
}

class _SpeakingBadge extends StatefulWidget {
  const _SpeakingBadge();
  @override
  State<_SpeakingBadge> createState() => _SpeakingBadgeState();
}

class _SpeakingBadgeState extends State<_SpeakingBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Transform.scale(
        scale: 0.9 + _ctrl.value * 0.2,
        child: CircleAvatar(
          radius: 10,
          backgroundColor: ThixPolicy.domainMedia,
          child: const Icon(Icons.graphic_eq_rounded, size: 12, color: Colors.white),
        ),
      ),
    );
  }
}

class _ReactionBurst extends StatefulWidget {
  final String emoji;
  const _ReactionBurst({super.key, required this.emoji});

  @override
  State<_ReactionBurst> createState() => _ReactionBurstState();
}

class _ReactionBurstState extends State<_ReactionBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 1, end: 0).animate(_ctrl),
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero).animate(_ctrl),
        child: Text(widget.emoji, style: const TextStyle(fontSize: 32)),
      ),
    );
  }
}
