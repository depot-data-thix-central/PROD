// lib/presentation/network/live/audio_space_room_screen.dart
//
// ============================================================================
// 🎙️ AUDIO SPACE ROOM SCREEN — style X Spaces (v3)
// ============================================================================
// ✅ Noms de TOUS les participants visibles (grille avatar + nom + rôle)
// ✅ « +N autres auditeurs » → liste complète (Sur scène / Demandes / Auditeurs)
// ✅ Chrono basé sur le début réel du salon (persistant)
// ✅ Réduire (chevron) : le salon continue, audio en arrière-plan
// ✅ Quitter / Terminer pour tous (hôte)
// ✅ Demander la parole / Annuler / micro (intervenants)
// ✅ Anneau animé sur celui qui parle
// ✅ Commentaires en fenêtre, réactions flottantes, partage, invitation
// ✅ Modération : inviter à parler, retirer le micro, couper, co-hôte, expulser
// ============================================================================

import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/data/models/live/audio_space_model.dart';
import 'package:thix_id/data/services/live/audio_space_controller.dart';
import 'package:thix_id/data/services/live/audio_space_manager.dart';
import 'package:thix_id/data/services/live/audio_space_share_service.dart';
import 'package:thix_id/features/auth/presentation/providers/auth_controller.dart';
import 'package:thix_id/l10n/app_localizations.dart';

// ════════════════════════════════════════════════════════════════════════
// CONSTANTS
// ════════════════════════════════════════════════════════════════════════
const Duration _kActionThrottle = Duration(milliseconds: 400);
const Duration _kChatThrottle = Duration(milliseconds: 600);
const int _kChatMaxLength = 300;
const int _kGridColumns = 4;
const int _kGridMax = 12;
const List<String> _kReactions = ['❤️', '👏', '🔥', '😂', '🙌', '🎉', '💯'];

// ════════════════════════════════════════════════════════════════════════
// HELPERS
// ════════════════════════════════════════════════════════════════════════
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

int _rank(AudioSpaceRole r) {
  switch (r) {
    case AudioSpaceRole.host:
      return 0;
    case AudioSpaceRole.cohost:
      return 1;
    case AudioSpaceRole.speaker:
      return 2;
    case AudioSpaceRole.listener:
      return 3;
  }
}

int _cmp(AudioSpaceParticipant a, AudioSpaceParticipant b) {
  final r = _rank(a.role).compareTo(_rank(b.role));
  if (r != 0) return r;
  return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
}

String _fmt(Duration d) {
  String two(int v) => v.toString().padLeft(2, '0');
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
}

Widget _spaceAvatar(String? url, double size) {
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
          ? CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => Icon(Icons.person,
                  size: size * 0.5, color: ThixPolicy.textSecondary),
            )
          : Icon(Icons.person,
              size: size * 0.5, color: ThixPolicy.textSecondary),
    ),
  );
}

// ════════════════════════════════════════════════════════════════════════
// PAGE PRINCIPALE
// ════════════════════════════════════════════════════════════════════════
class AudioSpaceRoomScreen extends ConsumerStatefulWidget {
  final AudioSpace space;
  const AudioSpaceRoomScreen({super.key, required this.space});

  @override
  ConsumerState<AudioSpaceRoomScreen> createState() =>
      _AudioSpaceRoomScreenState();
}

class _FloaterData {
  final int id;
  final String emoji;
  final double dx;
  _FloaterData(this.id, this.emoji, this.dx);
}

class _AudioSpaceRoomScreenState extends ConsumerState<AudioSpaceRoomScreen> {
  DateTime? _lastAction;
  StreamSubscription<Map<String, dynamic>>? _invitesSub;

  final List<_FloaterData> _floaters = [];
  int _floaterSeq = 0;
  bool _showReactions = false;
  bool _closing = false;

  // ════════════════════════════════════════════════════════════════════
  // LIFECYCLE
  // ════════════════════════════════════════════════════════════════════
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AudioSpaceManager.instance.roomOpen.value = true;
    });
    Future.microtask(_ensureJoined);
    _listenInvites();
  }

  @override
  void dispose() {
    _invitesSub?.cancel();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AudioSpaceManager.instance.roomOpen.value = false;
    });
    super.dispose();
  }

  Future<void> _ensureJoined() async {
    if (!mounted) return;
    final ctrl = ref.read(audioSpaceControllerProvider.notifier);
    final st = ref.read(audioSpaceControllerProvider);

    // Déjà dans CE salon (réduit puis rouvert) : on ne rejoint pas, le chrono continue
    if (st.isActive && st.spaceId == widget.space.id) return;

    if (st.isActive) {
      _snack('Quittez d\'abord le salon en cours.', error: true);
      if (mounted) Navigator.of(context).pop();
      return;
    }

    ctrl.acknowledge();

    final user = ref.read(authControllerProvider).value;
    bool isVerified = false;
    try {
      isVerified = (user as dynamic)?.isVerified ?? false;
    } catch (_) {
      isVerified = false;
    }

    await ctrl.join(
      space: widget.space,
      displayName: user?.displayName ?? 'Membre THIX',
      avatarUrl: user?.photoUrl,
      isVerified: isVerified,
    );
  }

  void _listenInvites() {
    final userId = ref.read(authControllerProvider).value?.id;
    if (userId == null) return;

    _invitesSub = AudioSpaceShareService.instance
        .watchInvites(userId)
        .listen((invite) {
      final inviteSpaceId = invite['space_id']?.toString();
      if (inviteSpaceId != widget.space.id) return;
      if (!mounted) return;
      _snack('📨 ${invite['invited_by_name'] ?? "Quelqu\'un"} vous a invité');
    });
  }

  // ════════════════════════════════════════════════════════════════════
  // HELPERS
  // ════════════════════════════════════════════════════════════════════
  String _tx(AppLocalizations l10n, String key, String fallback) {
    final v = l10n.t(key);
    if (v.isEmpty || v == key) return fallback;
    return v;
  }

  bool _throttleAction() {
    final now = DateTime.now();
    if (_lastAction != null && now.difference(_lastAction!) < _kActionThrottle) {
      return false;
    }
    _lastAction = now;
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

  void _addFloater(String emoji) {
    if (!mounted) return;
    final id = ++_floaterSeq;
    setState(() {
      _floaters.add(_FloaterData(id, emoji, math.Random().nextDouble() * 70));
      if (_floaters.length > 25) _floaters.removeAt(0);
    });
  }

  void _removeFloater(int id) {
    if (!mounted) return;
    setState(() => _floaters.removeWhere((f) => f.id == id));
  }

  // ════════════════════════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(audioSpaceControllerProvider);
    final ctrl = ref.read(audioSpaceControllerProvider.notifier);

    ref.listen<AudioSpaceManagerState>(audioSpaceControllerProvider,
        (prev, next) {
      if (next.noticeTick != (prev?.noticeTick ?? 0) && next.notice != null) {
        _snack(next.notice!);
      }
      if (next.reactionTick != (prev?.reactionTick ?? 0) &&
          next.reactionEmoji != null) {
        _addFloater(next.reactionEmoji!);
      }
      if (_closing || next.space?.id != widget.space.id) return;
      final kicked = next.status == ManagerStatus.error &&
          (next.errorMessage ?? '').contains('exclu');
      if (next.status == ManagerStatus.ended || kicked) {
        _closing = true;
        _snack(next.errorMessage ?? 'Salon terminé.', error: true);
        Future.microtask(() {
          ctrl.acknowledge();
          if (mounted) Navigator.of(context).maybePop();
        });
      }
    });

    return Scaffold(
      backgroundColor: ThixPolicy.tint,
      body: SafeArea(
        child: Stack(
          children: [
            _buildBody(l10n, state, ctrl),
            // Réactions flottantes
            Positioned.fill(
              child: IgnorePointer(
                child: Stack(
                  children: [
                    for (final f in _floaters)
                      _FloatingEmoji(
                        key: ValueKey(f.id),
                        emoji: f.emoji,
                        dx: f.dx,
                        onDone: () => _removeFloater(f.id),
                      ),
                  ],
                ),
              ),
            ),
            if (_showReactions) _reactionPicker(ctrl),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(
    AppLocalizations l10n,
    AudioSpaceManagerState state,
    AudioSpaceController ctrl,
  ) {
    // État d'un autre salon / pas encore initialisé : simple chargement
    if (state.space?.id != widget.space.id && !state.isActive) {
      return const Center(child: CircularProgressIndicator());
    }

    switch (state.status) {
      case ManagerStatus.idle:
      case ManagerStatus.joining:
        return const Center(child: CircularProgressIndicator());
      case ManagerStatus.ending:
        return _statusPane(ctrl, 'Fermeture du salon en cours...',
            Icons.hourglass_top_rounded);
      case ManagerStatus.ended:
      case ManagerStatus.error:
        return _statusPane(
          ctrl,
          state.errorMessage ??
              _tx(l10n, 'audio_space_error', 'Impossible de rejoindre le salon.'),
          Icons.error_outline,
        );
      case ManagerStatus.live:
      case ManagerStatus.background:
        return _buildLive(l10n, state, ctrl);
    }
  }

  Widget _statusPane(AudioSpaceController ctrl, String text, IconData icon) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: ThixPolicy.textSecondary),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center, style: ThixPolicy.bodyStyle),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                ctrl.acknowledge();
                Navigator.of(context).maybePop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: ThixPolicy.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Retour'),
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // LIVE
  // ════════════════════════════════════════════════════════════════════
  Widget _buildLive(
    AppLocalizations l10n,
    AudioSpaceManagerState state,
    AudioSpaceController ctrl,
  ) {
    final space = state.space ?? widget.space;

    return Column(
      children: [
        _topBar(l10n, state, ctrl),
        if (state.reconnecting)
          _banner('Reconnexion audio…', ThixPolicy.warning,
              Icons.wifi_off_rounded)
        else if (!state.audioReady)
          _banner('Connexion audio…', ThixPolicy.textSecondary,
              Icons.graphic_eq_rounded),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            children: [
              _statusRow(l10n, state, space),
              const SizedBox(height: 10),
              _TitleText(space.title),
              if (space.description.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(space.description,
                    style: const TextStyle(
                        fontSize: 13, color: ThixPolicy.textSecondary)),
              ],
              const SizedBox(height: 18),
              _people(l10n, state, ctrl),
            ],
          ),
        ),
        _bottomBar(l10n, state, ctrl),
      ],
    );
  }

  Widget _banner(String text, Color color, IconData icon) {
    return Container(
      width: double.infinity,
      color: color.withValues(alpha: 0.12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 8),
          Text(text, style: TextStyle(fontSize: 12, color: color)),
        ],
      ),
    );
  }

  // ── Barre du haut ──
  Widget _topBar(
    AppLocalizations l10n,
    AudioSpaceManagerState state,
    AudioSpaceController ctrl,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 12, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 34),
            tooltip: 'Réduire',
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.ios_share_rounded),
            tooltip: _tx(l10n, 'audio_space_share', 'Partager'),
            onPressed: () => _shareSpace(l10n, state, ctrl),
          ),
          IconButton(
            icon: const Icon(Icons.more_horiz_rounded),
            tooltip: 'Plus',
            onPressed: () => _moreSheet(l10n, state, ctrl),
          ),
          TextButton(
            onPressed: () => _confirmLeave(ctrl),
            child: Text(
              _tx(l10n, 'audio_space_leave', 'Quitter'),
              style: const TextStyle(
                  color: ThixPolicy.danger,
                  fontWeight: FontWeight.w800,
                  fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusRow(
    AppLocalizations l10n,
    AudioSpaceManagerState state,
    AudioSpace space,
  ) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 4,
      children: [
        if (space.recordingEnabled) const _RecChip(),
        const _LiveDot(),
        _ElapsedText(startedAt: state.startedAt),
        Text(
          '· ${state.participants.length} ${_tx(l10n, 'audio_space_listening', 'à l\'écoute')}',
          style: const TextStyle(fontSize: 14, color: ThixPolicy.textSecondary),
        ),
      ],
    );
  }

  // ── Grille des participants (noms visibles) ──
  Widget _people(
    AppLocalizations l10n,
    AudioSpaceManagerState state,
    AudioSpaceController ctrl,
  ) {
    final sorted = [...state.participants]..sort(_cmp);
    final onStage =
        sorted.where((p) => p.role != AudioSpaceRole.listener).toList();
    final listeners =
        sorted.where((p) => p.role == AudioSpaceRole.listener).toList();

    final maxShow = math.max(_kGridMax, onStage.length);
    final room = math.max(0, maxShow - onStage.length);
    final shownListeners = listeners.take(room).toList();
    final hidden = listeners.length - shownListeners.length;

    final canMod = ctrl.canModerate;

    return LayoutBuilder(builder: (context, c) {
      const gap = 8.0;
      final width =
          (c.maxWidth - gap * (_kGridColumns - 1)) / _kGridColumns;

      Widget cell(AudioSpaceParticipant p) => _PersonCell(
            width: width,
            p: p,
            speaking: state.speakingUserIds.contains(p.userId),
            isMe: p.userId == ctrl.myId,
            roleLabel: _roleLabel(l10n, p.role),
            showHand: p.handRaised && canMod,
            onTap: () => _personSheet(l10n, p, ctrl),
          );

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: gap,
            runSpacing: 18,
            children: [
              for (final p in onStage) cell(p),
              for (final p in shownListeners) cell(p),
            ],
          ),
          if (hidden > 0) ...[
            const SizedBox(height: 18),
            InkWell(
              onTap: () => _participantsSheet(l10n),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  border: Border.all(color: ThixPolicy.border),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '+$hidden ${_tx(l10n, 'audio_space_other_listeners', 'autres auditeurs')}',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded,
                        color: ThixPolicy.textSecondary),
                  ],
                ),
              ),
            ),
          ],
        ],
      );
    });
  }

  // ── Barre du bas ──
  Widget _bottomBar(
    AppLocalizations l10n,
    AudioSpaceManagerState state,
    AudioSpaceController ctrl,
  ) {
    final me = state.me;
    final canTalk = me?.role.canSpeak ?? false;
    final requests = state.participants
        .where((p) => p.handRaised && p.role == AudioSpaceRole.listener)
        .length;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: ThixPolicy.border)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _mainButton(l10n, me, canTalk, ctrl),
          const Spacer(),
          _iconButton(
            icon: Icons.people_alt_outlined,
            badge: ctrl.canModerate ? requests : 0,
            tooltip: 'Personnes',
            onTap: () => _participantsSheet(l10n),
          ),
          const SizedBox(width: 6),
          _iconButton(
            icon: _showReactions
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
            tooltip: 'Réactions',
            onTap: () => setState(() => _showReactions = !_showReactions),
          ),
          const SizedBox(width: 10),
          _commentPill(state.messages.length),
        ],
      ),
    );
  }

  Widget _mainButton(
    AppLocalizations l10n,
    AudioSpaceParticipant? me,
    bool canTalk,
    AudioSpaceController ctrl,
  ) {
    final IconData icon;
    final String label;
    final Color color;
    final VoidCallback? onTap;

    if (me == null) {
      icon = Icons.mic_none_rounded;
      label = '';
      color = ThixPolicy.textMuted;
      onTap = null;
    } else if (canTalk) {
      icon = me.isMuted ? Icons.mic_off_rounded : Icons.mic_rounded;
      label = me.isMuted
          ? _tx(l10n, 'audio_space_muted', 'Muet')
          : _tx(l10n, 'audio_space_live_mic', 'Micro actif');
      color = me.isMuted ? ThixPolicy.textSecondary : ThixPolicy.domainMedia;
      onTap = () {
        if (!_throttleAction()) return;
        HapticFeedback.selectionClick();
        ctrl.toggleMute();
      };
    } else {
      icon = me.handRaised
          ? Icons.back_hand_rounded
          : Icons.mic_none_rounded;
      label = me.handRaised
          ? _tx(l10n, 'audio_space_cancel_request', 'Annuler la demande')
          : _tx(l10n, 'audio_space_request', 'Demander');
      color = me.handRaised ? ThixPolicy.warning : ThixPolicy.textSecondary;
      onTap = () {
        if (!_throttleAction()) return;
        HapticFeedback.selectionClick();
        ctrl.toggleHandRaise();
      };
    }

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.08),
              border: Border.all(color: color.withValues(alpha: 0.6), width: 1.5),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: ThixPolicy.textSecondary)),
        ],
      ),
    );
  }

  Widget _iconButton({
    required IconData icon,
    required VoidCallback onTap,
    String? tooltip,
    int badge = 0,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: Icon(icon, size: 28, color: ThixPolicy.inkDeep),
          tooltip: tooltip,
          onPressed: onTap,
        ),
        if (badge > 0)
          Positioned(
            right: 2,
            top: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: ThixPolicy.danger,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('$badge',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800)),
            ),
          ),
      ],
    );
  }

  Widget _commentPill(int count) {
    return GestureDetector(
      onTap: _chatSheet,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: ThixPolicy.primary,
          borderRadius: BorderRadius.circular(26),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.chat_bubble_outline_rounded,
                color: Colors.white, size: 22),
            const SizedBox(width: 8),
            Text('$count',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15)),
          ],
        ),
      ),
    );
  }

  Widget _reactionPicker(AudioSpaceController ctrl) {
    return Positioned(
      left: 16,
      right: 16,
      bottom: 96,
      child: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(30),
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (final e in _kReactions)
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    ctrl.sendReaction(e);
                    _addFloater(e);
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(e, style: const TextStyle(fontSize: 26)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // SHEETS
  // ════════════════════════════════════════════════════════════════════
  Future<void> _participantsSheet(AppLocalizations l10n) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ParticipantsSheet(
        roleLabel: (r) => _roleLabel(l10n, r),
        onPerson: (p) {
          Navigator.of(context).pop();
          _personSheet(l10n, p, ref.read(audioSpaceControllerProvider.notifier));
        },
        onAccept: (p) {
          if (!_throttleAction()) return;
          ref.read(audioSpaceControllerProvider.notifier).promoteToSpeaker(p);
        },
      ),
    );
  }

  Future<void> _chatSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ChatSheet(),
    );
  }

  Future<void> _personSheet(
    AppLocalizations l10n,
    AudioSpaceParticipant p,
    AudioSpaceController ctrl,
  ) async {
    final isMe = p.userId == ctrl.myId;
    final canMod =
        ctrl.canModerate && !isMe && p.role != AudioSpaceRole.host;
    final amHost = ctrl.isHost;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 18),
            _spaceAvatar(p.avatarUrl, 76),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(p.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800)),
                ),
                if (p.isVerified)
                  const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Icon(Icons.verified_rounded,
                        size: 18, color: ThixPolicy.primary),
                  ),
              ],
            ),
            Text(_roleLabel(l10n, p.role),
                style: const TextStyle(color: ThixPolicy.textSecondary)),
            const SizedBox(height: 8),
            if (canMod) ...[
              const Divider(),
              if (p.role == AudioSpaceRole.listener)
                ListTile(
                  leading: const Icon(Icons.mic_rounded),
                  title: Text(_tx(l10n, 'audio_space_invite', 'Inviter à parler')),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    if (_throttleAction()) ctrl.promoteToSpeaker(p);
                  },
                ),
              if (p.role == AudioSpaceRole.speaker ||
                  p.role == AudioSpaceRole.cohost) ...[
                ListTile(
                  leading: Icon(p.isMuted
                      ? Icons.mic_rounded
                      : Icons.mic_off_rounded),
                  title: Text(p.isMuted ? 'Autoriser le micro' : 'Couper le micro'),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    if (_throttleAction()) ctrl.hostMute(p.userId, !p.isMuted);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.hearing_disabled_rounded),
                  title: Text(_tx(l10n, 'audio_space_remove_speaker',
                      'Retirer de la scène')),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    if (_throttleAction()) ctrl.demoteToListener(p);
                  },
                ),
              ],
              if (amHost && p.role != AudioSpaceRole.cohost)
                ListTile(
                  leading: const Icon(Icons.star_rounded),
                  title: const Text('Nommer co-hôte'),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    if (_throttleAction()) ctrl.promoteToCohost(p);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.block, color: ThixPolicy.danger),
                title: Text(_tx(l10n, 'audio_space_kick', 'Expulser'),
                    style: const TextStyle(color: ThixPolicy.danger)),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _confirmKick(l10n, p, ctrl);
                },
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _moreSheet(
    AppLocalizations l10n,
    AudioSpaceManagerState state,
    AudioSpaceController ctrl,
  ) async {
    final space = state.space ?? widget.space;
    final requests = state.participants
        .where((p) => p.handRaised && p.role == AudioSpaceRole.listener)
        .length;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.link_rounded),
              title: const Text('Copier le lien'),
              onTap: () {
                Navigator.pop(sheetCtx);
                Clipboard.setData(ClipboardData(text: space.shareLink));
                _snack('Lien copié');
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_add_alt_rounded),
              title: const Text('Inviter des contacts'),
              onTap: () {
                Navigator.pop(sheetCtx);
                _showInviteSheet(l10n);
              },
            ),
            ListTile(
              leading: const Icon(Icons.people_alt_outlined),
              title: Text(ctrl.canModerate
                  ? 'Personnes et demandes${requests > 0 ? ' ($requests)' : ''}'
                  : 'Personnes'),
              onTap: () {
                Navigator.pop(sheetCtx);
                _participantsSheet(l10n);
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline_rounded),
              title: const Text('À propos du salon'),
              onTap: () {
                Navigator.pop(sheetCtx);
                _aboutDialog(space, state, ctrl);
              },
            ),
            if (ctrl.canModerate)
              ListTile(
                leading: const Icon(Icons.volume_off_rounded),
                title: Text(_tx(l10n, 'audio_space_mute_all',
                    'Couper tous les micros')),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  if (_throttleAction()) ctrl.hostMuteAll();
                },
              ),
            if (ctrl.isHost)
              ListTile(
                leading: const Icon(Icons.stop_circle_rounded,
                    color: ThixPolicy.danger),
                title: const Text('Terminer le salon pour tous',
                    style: TextStyle(color: ThixPolicy.danger)),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _confirmEnd(l10n, ctrl);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _aboutDialog(
    AudioSpace space,
    AudioSpaceManagerState state,
    AudioSpaceController ctrl,
  ) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(space.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Hôte : ${ctrl.hostName}'),
            const SizedBox(height: 6),
            Text('Sujet : ${space.topic}'),
            const SizedBox(height: 6),
            Text('Durée : ${_fmt(state.elapsed)}'),
            const SizedBox(height: 6),
            Text('Participants : ${state.participants.length}'),
            if (space.description.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(space.description),
            ],
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Fermer')),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // PARTAGE / INVITATION
  // ════════════════════════════════════════════════════════════════════
  Future<void> _shareSpace(
    AppLocalizations l10n,
    AudioSpaceManagerState state,
    AudioSpaceController ctrl,
  ) async {
    if (!_throttleAction()) return;
    HapticFeedback.lightImpact();

    final me = ref.read(authControllerProvider).value;
    if (me == null) return;

    await AudioSpaceShareSheet.show(
      context,
      space: state.space ?? widget.space,
      currentUserId: me.id,
      currentUserName: me.displayName,
      listeners: ctrl.participants.length,
      hostName: ctrl.hostName,
    );
  }

  Future<void> _showInviteSheet(AppLocalizations l10n) async {
    if (!_throttleAction()) return;
    HapticFeedback.lightImpact();

    final me = ref.read(authControllerProvider).value;
    if (me == null) return;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _InviteContactsSheet(
        space: widget.space,
        currentUserId: me.id,
        currentUserName: me.displayName,
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // CONFIRMATIONS
  // ════════════════════════════════════════════════════════════════════
  Future<void> _confirmKick(
    AppLocalizations l10n,
    AudioSpaceParticipant p,
    AudioSpaceController ctrl,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
            _tx(l10n, 'audio_space_kick_confirm_title', 'Expulser ?')),
        content: Text(_tx(l10n, 'audio_space_kick_confirm_message',
            'Retirer ${p.displayName} du salon ?')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(_tx(l10n, 'audio_space_cancel', 'Annuler')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(_tx(l10n, 'audio_space_kick', 'Expulser'),
                style: const TextStyle(color: ThixPolicy.danger)),
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

  Future<void> _confirmEnd(
      AppLocalizations l10n, AudioSpaceController ctrl) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_tx(
            l10n, 'audio_space_end_confirm_title', 'Terminer le salon ?')),
        content: Text(_tx(l10n, 'audio_space_end_confirm_message',
            'Tous les participants seront déconnectés.')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(_tx(l10n, 'audio_space_cancel', 'Annuler')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(_tx(l10n, 'audio_space_end', 'Terminer'),
                style: const TextStyle(color: ThixPolicy.danger)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    HapticFeedback.mediumImpact();
    _closing = true;
    try {
      await ctrl.endSpace();
      if (mounted) Navigator.of(context).maybePop();
    } catch (e) {
      _closing = false;
      _snack(e.toString().replaceFirst('Exception: ', ''), error: true);
    }
  }

  Future<void> _confirmLeave(AudioSpaceController ctrl) async {
    final l10n = AppLocalizations.of(context);

    if (ctrl.isHost) {
      final action = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Que souhaitez-vous faire ?'),
          content: const Text(
              'Vous pouvez quitter (le salon continue sans vous) ou le terminer pour tout le monde.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, 'cancel'),
                child: const Text('Annuler')),
            TextButton(
                onPressed: () => Navigator.pop(ctx, 'leave'),
                child: const Text('Quitter')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'end'),
              child: const Text('Terminer pour tous',
                  style: TextStyle(color: ThixPolicy.danger)),
            ),
          ],
        ),
      );
      if (action == 'end') {
        await _confirmEnd(l10n, ctrl);
      } else if (action == 'leave') {
        await _doLeave(ctrl);
      }
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quitter le salon ?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(_tx(l10n, 'audio_space_cancel', 'Annuler'))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(_tx(l10n, 'audio_space_leave', 'Quitter'),
                style: const TextStyle(color: ThixPolicy.danger)),
          ),
        ],
      ),
    );
    if (ok == true) await _doLeave(ctrl);
  }

  Future<void> _doLeave(AudioSpaceController ctrl) async {
    if (!_throttleAction()) return;
    _closing = true;
    await ctrl.leave();
    if (mounted) Navigator.of(context).maybePop();
  }
}

// ════════════════════════════════════════════════════════════════════════
// CELLULE PARTICIPANT (avatar + NOM + rôle)
// ════════════════════════════════════════════════════════════════════════
class _PersonCell extends StatelessWidget {
  final double width;
  final AudioSpaceParticipant p;
  final bool speaking;
  final bool isMe;
  final bool showHand;
  final String roleLabel;
  final VoidCallback onTap;

  const _PersonCell({
    required this.width,
    required this.p,
    required this.speaking,
    required this.isMe,
    required this.showHand,
    required this.roleLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final avatarSize = (width - 8).clamp(40.0, 72.0);
    final onStage = p.role != AudioSpaceRole.listener;
    final name = isMe ? '${p.displayName} (vous)' : p.displayName;

    return SizedBox(
      width: width,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: speaking
                          ? ThixPolicy.domainMedia
                          : Colors.transparent,
                      width: 3,
                    ),
                  ),
                  child: _spaceAvatar(p.avatarUrl, avatarSize),
                ),
                if (onStage && p.isMuted)
                  const Positioned(
                    right: 0,
                    bottom: 0,
                    child: CircleAvatar(
                      radius: 10,
                      backgroundColor: Colors.black54,
                      child: Icon(Icons.mic_off, size: 12, color: Colors.white),
                    ),
                  ),
                if (showHand || (p.handRaised && isMe))
                  Positioned(
                    left: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                          color: Colors.amber, shape: BoxShape.circle),
                      child: const Icon(Icons.back_hand_rounded,
                          size: 12, color: Colors.white),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w800),
                  ),
                ),
                if (p.isVerified)
                  const Padding(
                    padding: EdgeInsets.only(left: 2),
                    child: Icon(Icons.verified_rounded,
                        size: 13, color: ThixPolicy.primary),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (p.role == AudioSpaceRole.host)
                  const Padding(
                    padding: EdgeInsets.only(right: 3),
                    child: Icon(Icons.graphic_eq_rounded,
                        size: 12, color: ThixPolicy.primary),
                  ),
                Flexible(
                  child: Text(
                    roleLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11, color: ThixPolicy.textSecondary),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// FENÊTRE PERSONNES (Sur scène / Demandes / Auditeurs)
// ════════════════════════════════════════════════════════════════════════
class _ParticipantsSheet extends ConsumerWidget {
  final String Function(AudioSpaceRole) roleLabel;
  final void Function(AudioSpaceParticipant) onPerson;
  final void Function(AudioSpaceParticipant) onAccept;

  const _ParticipantsSheet({
    required this.roleLabel,
    required this.onPerson,
    required this.onAccept,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(audioSpaceControllerProvider);
    final ctrl = ref.read(audioSpaceControllerProvider.notifier);
    final mod = ctrl.canModerate;

    final sorted = [...state.participants]..sort(_cmp);
    final onStage =
        sorted.where((p) => p.role != AudioSpaceRole.listener).toList();
    final listeners =
        sorted.where((p) => p.role == AudioSpaceRole.listener).toList();
    final requests = listeners.where((p) => p.handRaised).toList();

    Widget list(List<AudioSpaceParticipant> items, {bool request = false}) {
      if (items.isEmpty) {
        return const Center(
          child: Text('Personne pour le moment',
              style: TextStyle(color: ThixPolicy.textMuted)),
        );
      }
      return ListView.builder(
        itemCount: items.length,
        itemBuilder: (_, i) {
          final p = items[i];
          final isMe = p.userId == ctrl.myId;
          return ListTile(
            onTap: () => onPerson(p),
            leading: _spaceAvatar(p.avatarUrl, 42),
            title: Row(
              children: [
                Flexible(
                  child: Text(isMe ? '${p.displayName} (vous)' : p.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
                if (p.isVerified)
                  const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Icon(Icons.verified_rounded,
                        size: 15, color: ThixPolicy.primary),
                  ),
              ],
            ),
            subtitle: Text(roleLabel(p.role)),
            trailing: request && mod
                ? TextButton(
                    onPressed: () => onAccept(p),
                    child: const Text('Accepter'),
                  )
                : (p.handRaised && mod
                    ? const Icon(Icons.back_hand_rounded,
                        color: Colors.amber, size: 20)
                    : null),
          );
        },
      );
    }

    final tabs = <Tab>[
      Tab(text: 'Sur scène (${onStage.length})'),
      if (mod) Tab(text: 'Demandes (${requests.length})'),
      Tab(text: 'Auditeurs (${listeners.length})'),
    ];
    final views = <Widget>[
      list(onStage),
      if (mod) list(requests, request: true),
      list(listeners),
    ];

    return DefaultTabController(
      length: tabs.length,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                  color: ThixPolicy.border,
                  borderRadius: BorderRadius.circular(4)),
            ),
            const SizedBox(height: 8),
            TabBar(
              isScrollable: true,
              labelColor: ThixPolicy.primary,
              unselectedLabelColor: ThixPolicy.textSecondary,
              indicatorColor: ThixPolicy.primary,
              tabs: tabs,
            ),
            Expanded(child: TabBarView(children: views)),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// FENÊTRE COMMENTAIRES
// ════════════════════════════════════════════════════════════════════════
class _ChatSheet extends ConsumerStatefulWidget {
  const _ChatSheet();

  @override
  ConsumerState<_ChatSheet> createState() => _ChatSheetState();
}

class _ChatSheetState extends ConsumerState<_ChatSheet> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  DateTime? _last;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send() {
    final now = DateTime.now();
    if (_last != null && now.difference(_last!) < _kChatThrottle) return;
    _last = now;
    final clean = _SpaceSanitizer.chat(_input.text);
    if (clean.isEmpty) return;
    HapticFeedback.lightImpact();
    ref.read(audioSpaceControllerProvider.notifier).sendChat(clean);
    _input.clear();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(audioSpaceControllerProvider);
    final msgs = state.messages;
    final avatars = {for (final p in state.participants) p.userId: p.avatarUrl};

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                  color: ThixPolicy.border,
                  borderRadius: BorderRadius.circular(4)),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Text('Commentaires (${msgs.length})',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800)),
            ),
            const Divider(height: 1),
            Expanded(
              child: msgs.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Les commentaires du salon apparaissent ici pour tout le monde.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: ThixPolicy.textMuted),
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.all(14),
                      itemCount: msgs.length,
                      itemBuilder: (_, i) {
                        final m = msgs[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _spaceAvatar(avatars[m.userId], 30),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(m.displayName,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 13)),
                                    Text(m.body,
                                        style: const TextStyle(fontSize: 14)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _input,
                        maxLength: _kChatMaxLength,
                        inputFormatters: [
                          FilteringTextInputFormatter.deny(RegExp(r'[<>]')),
                        ],
                        decoration: InputDecoration(
                          counterText: '',
                          hintText: 'Ajouter un commentaire…',
                          filled: true,
                          fillColor: ThixPolicy.surfaceSoft,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(22),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                        ),
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                    IconButton(
                      onPressed: _send,
                      icon: const Icon(Icons.send_rounded,
                          color: ThixPolicy.primary),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// PETITS WIDGETS
// ════════════════════════════════════════════════════════════════════════
class _TitleText extends StatelessWidget {
  final String text;
  const _TitleText(this.text);

  @override
  Widget build(BuildContext context) {
    final spans = <InlineSpan>[];
    var last = 0;
    for (final m in RegExp(r'#[\p{L}\p{N}_]+', unicode: true).allMatches(text)) {
      if (m.start > last) spans.add(TextSpan(text: text.substring(last, m.start)));
      spans.add(TextSpan(
        text: m.group(0),
        style: const TextStyle(color: ThixPolicy.primary),
      ));
      last = m.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));

    return Text.rich(
      TextSpan(
        children: spans,
        style: const TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w900,
          height: 1.15,
          color: ThixPolicy.inkDeep,
        ),
      ),
    );
  }
}

class _ElapsedText extends StatefulWidget {
  final DateTime? startedAt;
  const _ElapsedText({required this.startedAt});

  @override
  State<_ElapsedText> createState() => _ElapsedTextState();
}

class _ElapsedTextState extends State<_ElapsedText> {
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.startedAt;
    var d = s == null ? Duration.zero : DateTime.now().difference(s);
    if (d.isNegative) d = Duration.zero;
    return Text(
      _fmt(d),
      style: const TextStyle(
        fontSize: 14,
        color: ThixPolicy.danger,
        fontWeight: FontWeight.w800,
        fontFeatures: [FontFeature.tabularFigures()],
      ),
    );
  }
}

class _RecChip extends StatelessWidget {
  const _RecChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: ThixPolicy.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
                color: ThixPolicy.danger, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          const Text('REC',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
        ],
      ),
    );
  }
}

class _LiveDot extends StatefulWidget {
  const _LiveDot();
  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
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
      builder: (_, __) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: ThixPolicy.danger,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: ThixPolicy.danger.withValues(alpha: 0.5 * _ctrl.value),
              blurRadius: 6,
              spreadRadius: 2 * _ctrl.value,
            ),
          ],
        ),
      ),
    );
  }
}

class _FloatingEmoji extends StatefulWidget {
  final String emoji;
  final double dx;
  final VoidCallback onDone;
  const _FloatingEmoji({
    super.key,
    required this.emoji,
    required this.dx,
    required this.onDone,
  });

  @override
  State<_FloatingEmoji> createState() => _FloatingEmojiState();
}

class _FloatingEmojiState extends State<_FloatingEmoji>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2200))
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) widget.onDone();
      })
      ..forward();
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
      builder: (_, __) {
        final t = Curves.easeOut.transform(_ctrl.value);
        return Positioned(
          right: 18 + widget.dx,
          bottom: 100 + t * 280,
          child: Opacity(
            opacity: (1 - _ctrl.value).clamp(0.0, 1.0),
            child: Text(widget.emoji, style: const TextStyle(fontSize: 30)),
          ),
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// INVITE CONTACTS SHEET
// ════════════════════════════════════════════════════════════════════════
class _InviteContactsSheet extends StatefulWidget {
  final AudioSpace space;
  final String currentUserId;
  final String currentUserName;
  const _InviteContactsSheet({
    required this.space,
    required this.currentUserId,
    required this.currentUserName,
  });

  @override
  State<_InviteContactsSheet> createState() => _InviteContactsSheetState();
}

class _InviteContactsSheetState extends State<_InviteContactsSheet> {
  final Set<String> _selected = {};
  bool _sending = false;

  @override
  Widget build(BuildContext context) {
    final service = AudioSpaceShareService.instance;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.98),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                    color: ThixPolicy.border,
                    borderRadius: BorderRadius.circular(4)),
              ),
            ),
            const SizedBox(height: 16),
            Text('Inviter des contacts',
                style: ThixPolicy.h3Style.copyWith(
                    color: ThixPolicy.inkDeep, fontWeight: FontWeight.w900)),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.4),
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: service.getInvitableContacts(widget.currentUserId),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator(
                            color: ThixPolicy.primary));
                  }
                  final contacts = snap.data ?? [];
                  if (contacts.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(20),
                      child: Center(
                        child: Text('Aucun contact à inviter',
                            style: ThixPolicy.captionStyle
                                .copyWith(color: ThixPolicy.textMuted)),
                      ),
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: contacts.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final c = contacts[i];
                      final id = c['id']?.toString() ?? '';
                      final name =
                          (c['display_name'] ?? c['full_name'] ?? 'Contact')
                              .toString();
                      final avatar = c['avatar_url']?.toString() ?? '';
                      final isSelected = _selected.contains(id);

                      return InkWell(
                        onTap: () => setState(() {
                          isSelected ? _selected.remove(id) : _selected.add(id);
                        }),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? ThixPolicy.primary.withValues(alpha: 0.08)
                                : ThixPolicy.surfaceSoft,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected
                                  ? ThixPolicy.primary
                                  : ThixPolicy.border,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: ThixPolicy.card,
                                backgroundImage: avatar.isNotEmpty
                                    ? NetworkImage(avatar)
                                    : null,
                                child: avatar.isEmpty
                                    ? const Icon(Icons.person,
                                        size: 20, color: ThixPolicy.textMuted)
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(name,
                                    style: ThixPolicy.labelStyle.copyWith(
                                        color: ThixPolicy.inkDeep,
                                        fontWeight: FontWeight.w700)),
                              ),
                              if (isSelected)
                                const Icon(Icons.check_circle_rounded,
                                    color: ThixPolicy.primary),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _selected.isEmpty || _sending
                    ? null
                    : () async {
                        setState(() => _sending = true);
                        try {
                          await service.inviteUsers(
                            space: widget.space,
                            userIds: _selected.toList(),
                            inviterName: widget.currentUserName,
                          );
                          if (mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    '📨 ${_selected.length} invitation(s) envoyée(s)'),
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            setState(() => _sending = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('⚠️ Erreur d\'envoi')),
                            );
                          }
                        }
                      },
                icon: _sending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_rounded, size: 18),
                label: Text(_selected.isEmpty
                    ? 'Sélectionner des contacts'
                    : 'Inviter (${_selected.length})'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8E24AA),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
