import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/data/models/live/audio_space_model.dart';
import 'package:thix_id/features/auth/presentation/providers/auth_controller.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/presentation/network/live/audio_space_controller.dart';

class AudioSpaceRoomScreen extends ConsumerStatefulWidget {
  final AudioSpace space;
  const AudioSpaceRoomScreen({super.key, required this.space});

  @override
  ConsumerState<AudioSpaceRoomScreen> createState() => _AudioSpaceRoomScreenState();
}

class _AudioSpaceRoomScreenState extends ConsumerState<AudioSpaceRoomScreen> {
  final _chatCtrl = TextEditingController();
  bool _started = false;

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(audioSpaceControllerProvider(widget.space));
    final ctrl = ref.read(audioSpaceControllerProvider(widget.space).notifier);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _leave(ctrl);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F3FF),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
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
                '${widget.space.topic} · ${state.listenerCount + state.participants.where((p) => p.role != AudioSpaceRole.listener).length} ${l10n.t('audio_space_people')}',
                style: TextStyle(fontSize: 12, color: ThixPolicy.textSecondary),
              ),
            ],
          ),
          actions: [
            if (ctrl.isHost)
              TextButton(
                onPressed: () async {
                  await ctrl.endSpace();
                  if (context.mounted) Navigator.pop(context);
                },
                child: Text(l10n.t('audio_space_end'), style: const TextStyle(color: ThixPolicy.danger)),
              ),
          ],
        ),
        body: _buildBody(l10n, state, ctrl),
      ),
    );
  }

  Widget _buildBody(AppLocalizations l10n, AudioSpaceState state, AudioSpaceController ctrl) {
    switch (state.status) {
      case AudioSpaceScreenStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case AudioSpaceScreenStatus.permissionDenied:
        return _statusPane(l10n.t('audio_space_mic_denied'), Icons.mic_off_rounded);
      case AudioSpaceScreenStatus.banned:
        return _statusPane(l10n.t('audio_space_banned'), Icons.block_rounded);
      case AudioSpaceScreenStatus.error:
        return _statusPane(state.errorMessage ?? l10n.t('audio_space_error'), Icons.error_outline);
      case AudioSpaceScreenStatus.ready:
        return Column(
          children: [
            if (widget.space.recordingEnabled)
              Container(
                width: double.infinity,
                color: const Color(0xFFFFF3CD),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  l10n.t('audio_space_recording_notice'),
                  style: const TextStyle(fontSize: 12, color: Color(0xFF7A5B00)),
                ),
              ),
            Expanded(child: _speakersGrid(l10n, state, ctrl)),
            _chatList(state),
            _composer(l10n, ctrl),
            _controls(l10n, state, ctrl),
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
            Text(text, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _speakersGrid(AppLocalizations l10n, AudioSpaceState state, AudioSpaceController ctrl) {
    final speakers = state.participants.where((p) => p.role != AudioSpaceRole.listener).toList();
    final raised = state.participants.where((p) => p.handRaised).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      children: [
        Text(l10n.t('audio_space_speakers'), style: ThixPolicy.h2Style.copyWith(fontSize: 14)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            for (final p in speakers)
              _person(p, ctrl, canModerate: ctrl.isHost || state.myRole == AudioSpaceRole.cohost),
          ],
        ),
        if (raised.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(l10n.t('audio_space_requests'), style: ThixPolicy.h2Style.copyWith(fontSize: 14)),
          const SizedBox(height: 8),
          for (final p in raised)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: _avatar(p.avatarUrl, 36),
              title: Text(p.displayName),
              trailing: ctrl.isHost
                  ? TextButton(
                      onPressed: () => ctrl.promote(p),
                      child: Text(l10n.t('audio_space_invite')),
                    )
                  : const Icon(Icons.back_hand_outlined, color: Color(0xFF7C4DFF)),
            ),
        ],
      ],
    );
  }

  Widget _person(AudioSpaceParticipant p, AudioSpaceController ctrl, {required bool canModerate}) {
    return GestureDetector(
      onLongPress: canModerate && p.role != AudioSpaceRole.host
          ? () => _moderationSheet(p, ctrl)
          : null,
      child: SizedBox(
        width: 84,
        child: Column(
          children: [
            Stack(
              children: [
                _avatar(p.avatarUrl, 64),
                if (!p.isMuted)
                  const Positioned(
                    right: 0,
                    bottom: 0,
                    child: CircleAvatar(
                      radius: 10,
                      backgroundColor: Color(0xFF7C4DFF),
                      child: Icon(Icons.graphic_eq_rounded, size: 12, color: Colors.white),
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
            Text(p.role.name, style: TextStyle(fontSize: 10, color: ThixPolicy.textSecondary)),
          ],
        ),
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
        border: Border.all(color: const Color(0xFFD7C9FF)),
      ),
      child: ClipOval(
        child: (url != null && url.isNotEmpty)
            ? CachedNetworkImage(imageUrl: url, fit: BoxFit.cover)
            : Icon(Icons.person, size: size * 0.5, color: ThixPolicy.textSecondary),
      ),
    );
  }

  Widget _chatList(AudioSpaceState state) {
    if (state.messages.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 110,
      child: ListView.builder(
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
              maxLength: 300,
              inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'[<>]'))],
              decoration: InputDecoration(
                counterText: '',
                hintText: l10n.t('audio_space_chat_hint'),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ),
          IconButton(
            onPressed: () {
              final user = ref.read(authControllerProvider).value;
              ctrl.sendChat(_chatCtrl.text, user?.displayName ?? 'Membre');
              _chatCtrl.clear();
            },
            icon: const Icon(Icons.send_rounded, color: Color(0xFF7C4DFF)),
          ),
        ],
      ),
    );
  }

  Widget _controls(AppLocalizations l10n, AudioSpaceState state, AudioSpaceController ctrl) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _roundBtn(
              icon: state.isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
              color: state.isMuted ? ThixPolicy.textSecondary : const Color(0xFF7C4DFF),
              label: state.isMuted ? l10n.t('audio_space_muted') : l10n.t('audio_space_live_mic'),
              onTap: ctrl.canSpeak || ctrl.isHost ? ctrl.toggleMute : null,
            ),
            if (!ctrl.isHost && state.myRole == AudioSpaceRole.listener)
              _roundBtn(
                icon: state.handRaised ? Icons.back_hand_rounded : Icons.back_hand_outlined,
                color: const Color(0xFF7C4DFF),
                label: l10n.t('audio_space_request'),
                onTap: ctrl.toggleHand,
              ),
            _roundBtn(
              icon: Icons.logout_rounded,
              color: ThixPolicy.danger,
              label: l10n.t('audio_space_leave'),
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
            child: Icon(icon, color: color),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 11, color: ThixPolicy.textSecondary)),
        ],
      ),
    );
  }

  Future<void> _moderationSheet(AudioSpaceParticipant p, AudioSpaceController ctrl) async {
    final l10n = AppLocalizations.of(context);
    await showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: Text(p.displayName), subtitle: Text(p.role.name)),
            if (p.role == AudioSpaceRole.listener)
              ListTile(
                leading: const Icon(Icons.mic),
                title: Text(l10n.t('audio_space_invite')),
                onTap: () {
                  Navigator.pop(context);
                  ctrl.promote(p);
                },
              ),
            if (p.role == AudioSpaceRole.speaker || p.role == AudioSpaceRole.cohost)
              ListTile(
                leading: const Icon(Icons.hearing_disabled),
                title: Text(l10n.t('audio_space_remove_speaker')),
                onTap: () {
                  Navigator.pop(context);
                  ctrl.demote(p);
                },
              ),
            ListTile(
              leading: const Icon(Icons.block, color: ThixPolicy.danger),
              title: Text(l10n.t('audio_space_kick')),
              onTap: () {
                Navigator.pop(context);
                ctrl.kick(p);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _leave(AudioSpaceController ctrl) async {
    if (ctrl.isHost) {
      await ctrl.endSpace();
    } else {
      await ctrl.leave();
    }
    if (mounted) Navigator.pop(context);
  }
}
