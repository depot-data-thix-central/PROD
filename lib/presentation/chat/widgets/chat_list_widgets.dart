// lib/presentation/chat/widgets/chat_list_widgets.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/features/network/presentation/providers/user_profile_providers.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/models/certification_tier.dart';
import 'package:thix_id/models/chat/chat_conversation.dart';
import 'package:thix_id/models/chat/chat_message.dart';
import 'package:thix_id/presentation/certification/widgets/certification_name_badge.dart';
import 'package:thix_id/services/biometric_service.dart';

const int kMaxLockAttempts = 5;
const int kLockCooldownSeconds = 30;
const int kPwdIterations = 5000;
const String kLockPwdKey = 'thix_chat_lock_pwd_v1';
const String kNotesKey = 'thix_chat_notes_v1';

/// Neutre (remplace le bleu).
const Color kInk = ThixPolicy.inkDeep;

/// i18n avec repli français si la clé n'existe pas encore.
String clS(BuildContext ctx, String key, {List<String>? args, String? fb}) {
  final l10n = AppLocalizations.of(ctx);
  final r = args == null ? l10n.t(key) : l10n.t(key, args: args);
  return (fb != null && r == key) ? fb : r;
}

// ============================================================================
// VALIDATEURS
// ============================================================================
class ChatListValidators {
  ChatListValidators._();

  static final RegExp _ctrlKeepNl = RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]');
  static final RegExp _ctrlAll = RegExp(r'[\x00-\x1F\x7F]');
  static final RegExp _bidi = RegExp(r'[\u200B\u200E\u200F\u202A-\u202E\u2066-\u2069\uFEFF]');
  static final RegExp _tags = RegExp(r'<[a-zA-Z/!?][^>]*>');
  static final RegExp _jsScheme = RegExp(r'(javascript|vbscript)\s*:', caseSensitive: false);
  static final RegExp _spaces = RegExp(r'\s+');
  static final RegExp _b64 = RegExp(r'^[A-Za-z0-9+/=]+$');

  static String sanitize(String? input, {int maxLength = 500, bool singleLine = false}) {
    if (input == null || input.trim().isEmpty) return '';
    var s = input;
    if (s.contains('<')) {
      final doc = html_parser.parse(s);
      s = doc.body?.text ?? s;
    }
    s = s
        .replaceAll('\r\n', '\n')
        .replaceAll(_tags, '')
        .replaceAll(_jsScheme, '')
        .replaceAll(_ctrlKeepNl, '')
        .replaceAll(_bidi, '');
    if (singleLine) s = s.replaceAll(_spaces, ' ');
    s = s.trim();
    if (s.length > maxLength) {
      var end = maxLength;
      final unit = s.codeUnitAt(end - 1);
      if (unit >= 0xD800 && unit <= 0xDBFF) end--;
      s = s.substring(0, end);
    }
    return s;
  }

  static String? sanitizeUrl(String? url) {
    if (url == null) return null;
    final t = url.trim().replaceAll(_ctrlAll, '');
    if (t.isEmpty || t.length > 2048) return null;
    final u = Uri.tryParse(t);
    if (u == null || !u.hasAuthority || u.host.isEmpty) return null;
    if (u.scheme != 'http' && u.scheme != 'https') return null;
    return t;
  }

  static String safeInitial(String? name) {
    final s = sanitize(name, maxLength: 10);
    if (s.isEmpty) return '?';
    return String.fromCharCode(s.runes.first).toUpperCase();
  }

  static bool isEncrypted(String? raw) {
    if (raw == null || raw.isEmpty) return false;
    final t = raw.trim();
    if (t.startsWith('ENCv1:') || t.startsWith('🔒')) return true;
    return t.length > 20 && !t.contains(' ') && _b64.hasMatch(t.replaceFirst(RegExp(r'^ENCv1:'), ''));
  }

  static bool _ends(String? n, List<String> exts) {
    if (n == null) return false;
    final l = n.toLowerCase();
    return exts.any(l.endsWith);
  }

  static bool isImageFile(String? n) => _ends(n, const ['.jpg', '.jpeg', '.png', '.gif', '.webp']);
  static bool isVideoFile(String? n) => _ends(n, const ['.mp4', '.mov', '.avi', '.mkv', '.webm']);
  static bool isAudioFile(String? n) => _ends(n, const ['.mp3', '.wav', '.m4a', '.ogg', '.aac']) || (n?.contains('Message audio (') ?? false);

  static int passwordScore(String pwd) {
    int score = 0;
    if (pwd.length >= 8) score++;
    if (pwd.length >= 12) score++;
    if (pwd.contains(RegExp(r'[a-z]')) && pwd.contains(RegExp(r'[A-Z]'))) score++;
    if (pwd.contains(RegExp(r'[0-9]'))) score++;
    if (pwd.contains(RegExp(r'[^\w\s]'))) score++;
    return score;
  }

  static bool isMissedCallText(String content) {
    final low = content.toLowerCase();
    return low.contains('manqué') || low.contains('missed') || low.contains('sans réponse');
  }
}

// ============================================================================
// 🔒 COFFRE LOCAL : mot de passe salé + hashé, anti-force-brute
// Format : v2:<sel base64>:<hash base64> (ancien format migré automatiquement)
// ============================================================================
class ChatLockVault {
  ChatLockVault._();

  static int _fails = 0;
  static DateTime? _lockedUntil;

  static int get cooldownRemaining {
    final u = _lockedUntil;
    if (u == null) return 0;
    final r = u.difference(DateTime.now()).inSeconds;
    if (r <= 0) {
      _lockedUntil = null;
      _fails = 0;
      return 0;
    }
    return r + 1;
  }

  static Future<String?> _read() async => (await SharedPreferences.getInstance()).getString(kLockPwdKey);

  static Future<bool> hasPassword() async => (await _read()) != null;

  static List<int> _derive(List<int> salt, String pwd) {
    final pb = utf8.encode(pwd);
    var h = sha256.convert([...salt, ...pb]).bytes;
    for (var i = 0; i < kPwdIterations; i++) {
      h = sha256.convert([...h, ...salt, ...pb]).bytes;
    }
    return h;
  }

  static bool _constEq(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var d = 0;
    for (var i = 0; i < a.length; i++) {
      d |= a[i] ^ b[i];
    }
    return d == 0;
  }

  static Future<void> setPassword(String pwd) async {
    final rng = math.Random.secure();
    final salt = List<int>.generate(16, (_) => rng.nextInt(256));
    final hash = _derive(salt, pwd);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kLockPwdKey, 'v2:${base64Encode(salt)}:${base64Encode(hash)}');
  }

  static Future<bool> verify(String pwd) async {
    if (cooldownRemaining > 0) return false;
    final stored = await _read();
    if (stored == null) return false;
    var ok = false;
    try {
      if (stored.startsWith('v2:')) {
        final p = stored.split(':');
        if (p.length == 3) ok = _constEq(_derive(base64Decode(p[1]), pwd), base64Decode(p[2]));
      } else {
        ok = utf8.decode(base64Decode(stored)) == pwd;
        if (ok) await setPassword(pwd);
      }
    } catch (_) {
      ok = false;
    }
    if (ok) {
      _fails = 0;
      _lockedUntil = null;
    } else {
      _fails++;
      if (_fails >= kMaxLockAttempts) {
        _lockedUntil = DateTime.now().add(const Duration(seconds: kLockCooldownSeconds));
      }
    }
    return ok;
  }
}

// ============================================================================
// DIALOGUES
// ============================================================================
class DefinePasswordDialog extends StatefulWidget {
  const DefinePasswordDialog({super.key});
  @override
  State<DefinePasswordDialog> createState() => _DefinePasswordDialogState();
}

class _DefinePasswordDialogState extends State<DefinePasswordDialog> {
  final _pass = TextEditingController();
  final _confirm = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _pass.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    if (ChatListValidators.passwordScore(_pass.text) < 3) {
      setState(() => _error = clS(context, 'chatlist_lock_weak'));
      return;
    }
    if (_pass.text != _confirm.text) {
      setState(() => _error = clS(context, 'chatlist_lock_mismatch'));
      return;
    }
    setState(() => _saving = true);
    await ChatLockVault.setPassword(_pass.text);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final score = ChatListValidators.passwordScore(_pass.text);
    return AlertDialog(
      backgroundColor: ThixPolicy.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rLg)),
      title: Row(children: [
        const Icon(Icons.lock_outline_rounded, color: ThixPolicy.danger, size: 22),
        const SizedBox(width: 10),
        Expanded(child: Text(clS(context, 'chatlist_lock_define_title'), style: ThixPolicy.titleStyle.copyWith(fontWeight: ThixPolicy.bold, fontSize: 16))),
      ]),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(clS(context, 'chatlist_lock_define_sub'), style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textSecondary)),
          const SizedBox(height: 12),
          TextField(controller: _pass, obscureText: true, onChanged: (_) => setState(() => _error = null), decoration: InputDecoration(labelText: clS(context, 'chatlist_lock_pwd'))),
          const SizedBox(height: 6),
          Row(
            children: List.generate(
              5,
              (i) => Expanded(
                child: Container(
                  height: 4,
                  margin: const EdgeInsets.only(right: 3),
                  decoration: BoxDecoration(color: i < score ? (score >= 3 ? ThixPolicy.success : ThixPolicy.warning) : ThixPolicy.border, borderRadius: BorderRadius.circular(2)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextField(controller: _confirm, obscureText: true, onChanged: (_) => setState(() => _error = null), decoration: InputDecoration(labelText: clS(context, 'chatlist_lock_pwd_confirm'))),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: const TextStyle(color: ThixPolicy.danger, fontSize: 12))),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(clS(context, 'common_cancel'))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: kInk),
          onPressed: _saving ? null : _save,
          child: Text(clS(context, 'chatlist_lock_save'), style: const TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

class UnlockDialog extends StatefulWidget {
  final String name;
  final bool bioAvailable;
  const UnlockDialog({super.key, required this.name, required this.bioAvailable});
  @override
  State<UnlockDialog> createState() => _UnlockDialogState();
}

class _UnlockDialogState extends State<UnlockDialog> {
  final _ctrl = TextEditingController();
  String? _error;
  bool _busy = false;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    if (ChatLockVault.cooldownRemaining > 0) _startTick();
  }

  void _startTick() {
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (ChatLockVault.cooldownRemaining <= 0) {
        _tick?.cancel();
        setState(() => _error = null);
      } else {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || ChatLockVault.cooldownRemaining > 0) return;
    setState(() => _busy = true);
    final ok = await ChatLockVault.verify(_ctrl.text);
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, true);
      return;
    }
    setState(() {
      _busy = false;
      _error = clS(context, 'chatlist_lock_bad_pwd');
    });
    if (ChatLockVault.cooldownRemaining > 0) _startTick();
  }

  Future<void> _bio() async {
    try {
      final ok = await BiometricService.instance.authenticate(reason: clS(context, 'chatlist_biometric_reason', args: [widget.name]));
      if (mounted && ok == true) Navigator.pop(context, true);
    } catch (e) {
      debugPrint('[ChatList] ⚠️ Biometric error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cd = ChatLockVault.cooldownRemaining;
    final msg = cd > 0 ? clS(context, 'chatlist_lock_cooldown', args: ['$cd']) : _error;
    return AlertDialog(
      backgroundColor: ThixPolicy.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rLg)),
      title: Row(children: [
        const Icon(Icons.lock_rounded, color: ThixPolicy.danger, size: 22),
        const SizedBox(width: 10),
        Expanded(child: Text(clS(context, 'chatlist_locked_title'), style: ThixPolicy.titleStyle.copyWith(fontWeight: ThixPolicy.bold, fontSize: 16))),
      ]),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(widget.name, style: ThixPolicy.bodyStyle.copyWith(fontWeight: ThixPolicy.semiBold)),
        const SizedBox(height: 12),
        TextField(
          controller: _ctrl,
          obscureText: true,
          autofocus: true,
          enabled: cd == 0,
          onChanged: (_) => setState(() => _error = null),
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(labelText: clS(context, 'chatlist_lock_pwd')),
        ),
        if (msg != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(msg, style: const TextStyle(color: ThixPolicy.danger, fontSize: 12))),
      ]),
      actions: [
        if (widget.bioAvailable)
          TextButton(
            onPressed: _bio,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.fingerprint_rounded, size: 18),
              const SizedBox(width: 6),
              Text(clS(context, 'chatlist_use_biometric')),
            ]),
          ),
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(clS(context, 'common_cancel'))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: kInk),
          onPressed: (_busy || cd > 0) ? null : _submit,
          child: Text(clS(context, 'chatlist_unlock_open'), style: const TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

// ============================================================================
// 📓 BLOC-NOTES
// ============================================================================
class NotebookSheet extends StatefulWidget {
  final SharedPreferences prefs;
  const NotebookSheet({super.key, required this.prefs});
  @override
  State<NotebookSheet> createState() => _NotebookSheetState();
}

class _NotebookSheetState extends State<NotebookSheet> {
  late final TextEditingController _ctrl = TextEditingController(text: widget.prefs.getString(kNotesKey) ?? '');
  Timer? _debounce;
  late int _len = _ctrl.text.length;

  @override
  void dispose() {
    _debounce?.cancel();
    unawaited(widget.prefs.setString(kNotesKey, _ctrl.text));
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    setState(() => _len = v.length);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 700), () => unawaited(widget.prefs.setString(kNotesKey, v)));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: const BoxDecoration(color: ThixPolicy.card, borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: ThixPolicy.border, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 12),
          Row(children: [
            const Icon(Icons.menu_book_outlined, color: kInk),
            const SizedBox(width: 8),
            Expanded(child: Text(clS(context, 'chatlist_notebook'), style: ThixPolicy.titleStyle.copyWith(fontWeight: ThixPolicy.bold))),
            Text('$_len', style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textMuted)),
          ]),
          const SizedBox(height: 10),
          Expanded(
            child: TextField(
              controller: _ctrl,
              maxLines: null,
              expands: true,
              maxLength: 20000,
              buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
              textAlignVertical: TextAlignVertical.top,
              style: ThixPolicy.bodyStyle,
              decoration: InputDecoration(
                hintText: clS(context, 'chatlist_notebook_hint'),
                hintStyle: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textSecondary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                contentPadding: const EdgeInsets.all(12),
              ),
              onChanged: _onChanged,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: kInk, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              onPressed: () => Navigator.pop(context, true),
              child: Text(clS(context, 'chatlist_notebook_save'), style: const TextStyle(color: Colors.white)),
            ),
          ),
        ]),
      ),
    );
  }
}

// ============================================================================
// APERÇU
// ============================================================================
class ChatListPreview {
  final String text;
  final String? prefix;
  final IconData? icon;
  final Color? color;
  final bool strong;
  const ChatListPreview(this.text, {this.prefix, this.icon, this.color, this.strong = false});
}

// ============================================================================
// PULSE
// ============================================================================
class PulseDot extends StatefulWidget {
  final Color color;
  final double size;
  const PulseDot({super.key, required this.color, this.size = 10});
  @override
  State<PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween<double>(begin: 0.8, end: 1.25).animate(_c),
      child: FadeTransition(
        opacity: Tween<double>(begin: 1.0, end: 0.45).animate(_c),
        child: Container(width: widget.size, height: widget.size, decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle)),
      ),
    );
  }
}

class PulseWrap extends StatefulWidget {
  final Widget child;
  final bool active;
  const PulseWrap({super.key, required this.child, required this.active});
  @override
  State<PulseWrap> createState() => _PulseWrapState();
}

class _PulseWrapState extends State<PulseWrap> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void initState() {
    super.initState();
    if (widget.active) _c.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant PulseWrap old) {
    super.didUpdateWidget(old);
    if (widget.active && !_c.isAnimating) {
      _c.repeat(reverse: true);
    } else if (!widget.active && _c.isAnimating) {
      _c.stop();
      _c.value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return widget.child;
    return FadeTransition(opacity: _c.drive(Tween<double>(begin: 1.0, end: 0.35)), child: widget.child);
  }
}

// ============================================================================
// FEUX DE STATUT (vert lu · orange distribué · gris envoyé)
// ============================================================================
class ListMessageStatusLights extends StatelessWidget {
  final bool isDelivered;
  final bool isRead;
  final bool show;
  const ListMessageStatusLights({super.key, this.isDelivered = false, this.isRead = false, this.show = true});

  factory ListMessageStatusLights.fromMessage(ChatMessage? msg, String currentUserId) {
    if (msg == null || msg.senderId != currentUserId || '${msg.mediaType ?? ''}'.startsWith('call_')) {
      return const ListMessageStatusLights(show: false);
    }
    return ListMessageStatusLights(isDelivered: msg.isDelivered, isRead: msg.isRead);
  }

  @override
  Widget build(BuildContext context) {
    if (!show) return const SizedBox.shrink();
    return Container(
      width: 9,
      height: 18,
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(color: kInk.withOpacity(0.8), borderRadius: BorderRadius.circular(5)),
      child: Column(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        _dot(ThixPolicy.success, isRead),
        _dot(ThixPolicy.warning, !isRead && isDelivered),
        _dot(ThixPolicy.textMuted, !isRead && !isDelivered),
      ]),
    );
  }

  Widget _dot(Color base, bool active) => Container(width: 5, height: 5, decoration: BoxDecoration(shape: BoxShape.circle, color: active ? base : base.withOpacity(0.22)));
}

// ============================================================================
// AVATARS D'ESCALADE : client (anneau gris foncé) + agent (anneau rouge)
// ============================================================================
class EscalationAvatars extends StatelessWidget {
  final String clientName;
  final String? clientAvatar;
  final String agentName;
  final String? agentAvatar;
  final bool pending;
  const EscalationAvatars({super.key, required this.clientName, this.clientAvatar, required this.agentName, this.agentAvatar, this.pending = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 62,
      height: 46,
      child: Stack(clipBehavior: Clip.none, children: [
        Positioned(left: 0, top: 4, child: _mini(clientAvatar, clientName, kInk)),
        Positioned(left: 24, top: 4, child: _mini(agentAvatar, agentName, ThixPolicy.danger)),
        Positioned(
          right: 0,
          bottom: 0,
          child: Stack(alignment: Alignment.center, children: [
            if (pending) const PulseDot(color: ThixPolicy.danger, size: 16),
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(color: ThixPolicy.danger, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5)),
              child: const Icon(Icons.swap_vert_rounded, size: 10, color: Colors.white),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _mini(String? url, String name, Color ring) {
    final safeName = ChatListValidators.sanitize(name, maxLength: 30);
    return Container(
      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: ring, width: 2), boxShadow: ThixPolicy.shadowSoft(opacity: 0.05)),
      child: CircleAvatar(
        radius: 17,
        backgroundColor: ring.withOpacity(0.15),
        backgroundImage: url != null ? CachedNetworkImageProvider(url) : null,
        child: url == null ? Text(ChatListValidators.safeInitial(safeName), style: ThixPolicy.labelStyle.copyWith(color: ring)) : null,
      ),
    );
  }
}

// ============================================================================
// TUILE DE CONVERSATION
// ============================================================================
class ConversationTile extends StatelessWidget {
  final ChatConversation conv;
  final String chatName;
  final String? chatAvatar;
  final bool isOnline;
  final bool unread;
  final bool isSelected;
  final bool escalationPending;
  final String currentUserId;
  final String otherUserId;
  final ChatMessage? lastMessage;
  final String timeText;
  final ChatListPreview preview;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onContextMenu;

  const ConversationTile({
    super.key,
    required this.conv,
    required this.chatName,
    required this.chatAvatar,
    required this.isOnline,
    required this.unread,
    required this.isSelected,
    required this.escalationPending,
    required this.currentUserId,
    required this.otherUserId,
    required this.lastMessage,
    required this.timeText,
    required this.preview,
    required this.onTap,
    required this.onLongPress,
    required this.onContextMenu,
  });

  @override
  Widget build(BuildContext context) {
    final isEsc = conv.isEscalation;
    final muted = conv.isCurrentlyMuted;
    final clientName = ChatListValidators.sanitize(conv.clientName ?? chatName, maxLength: 40);
    final agentName = ChatListValidators.sanitize(conv.escalatedByName ?? clS(context, 'chatlist_agent'), maxLength: 40);
    final clientAvatar = ChatListValidators.sanitizeUrl(conv.clientAvatar ?? chatAvatar);
    final agentAvatar = ChatListValidators.sanitizeUrl(conv.agentAvatar);

    // Fond : sélection > escalade > non lu > transparent (aucun bleu)
    final Color bg = isSelected
        ? kInk.withOpacity(0.10)
        : (isEsc ? ThixPolicy.danger.withOpacity(0.05) : (unread ? kInk.withOpacity(0.045) : Colors.transparent));

    final baseStyle = ThixPolicy.bodySmallStyle.copyWith(
      fontWeight: unread || preview.strong ? ThixPolicy.semiBold : ThixPolicy.regular,
      color: preview.color ?? (unread ? ThixPolicy.textMain : ThixPolicy.textSecondary),
    );

    return Semantics(
      button: true,
      label: '$chatName. ${isEsc ? "${clS(context, 'chatlist_escalated', fb: 'Escaladée')}. " : ""}${unread ? "${conv.unreadCount} ${clS(context, 'chatlist_unread_label')}. " : ""}${preview.text}',
      child: Material(
        color: bg,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Stack(children: [
            // Barres gauches : escalade = rouge + gris foncé, épinglé = or
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: isEsc
                  ? PulseWrap(
                      active: escalationPending,
                      child: Row(children: [
                        Container(width: 4, color: ThixPolicy.danger),
                        const SizedBox(width: 2),
                        Container(width: 4, color: kInk),
                      ]),
                    )
                  : Container(width: 3, color: conv.isPinned ? ThixPolicy.gold : Colors.transparent),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s20, vertical: 12),
              child: Row(children: [
                Stack(children: [
                  if (isEsc)
                    EscalationAvatars(clientName: clientName, clientAvatar: clientAvatar, agentName: agentName, agentAvatar: agentAvatar, pending: escalationPending)
                  else
                    Stack(children: [
                      Container(
                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: ThixPolicy.card, width: 1.5), boxShadow: ThixPolicy.shadowSoft(opacity: 0.03)),
                        child: CircleAvatar(
                          radius: 26,
                          backgroundColor: ThixPolicy.surface,
                          backgroundImage: chatAvatar != null ? CachedNetworkImageProvider(chatAvatar!) : null,
                          child: chatAvatar == null ? Text(ChatListValidators.safeInitial(chatName), style: ThixPolicy.h3Style.copyWith(color: ThixPolicy.textSecondary)) : null,
                        ),
                      ),
                      if (!conv.isGroup && isOnline)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(width: 14, height: 14, decoration: BoxDecoration(color: ThixPolicy.success, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2.5))),
                        ),
                    ]),
                  if (isSelected)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(color: kInk, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                        child: const Icon(Icons.check, size: 14, color: Colors.white),
                      ),
                    ),
                ]),
                const SizedBox(width: ThixPolicy.s16),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: _NameRow(conv: conv, chatName: chatName, otherUserId: otherUserId, unread: unread, muted: muted)),
                      const SizedBox(width: 8),
                      Text(
                        timeText,
                        style: ThixPolicy.captionStyle.copyWith(
                          fontWeight: unread ? ThixPolicy.bold : ThixPolicy.medium,
                          color: unread && !muted ? kInk : ThixPolicy.textSecondary,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.more_vert_rounded, size: 18, color: ThixPolicy.textSecondary),
                        onPressed: onContextMenu,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                    ]),
                    // ── SIGNE D'ESCALADE ──
                    if (isEsc)
                      Container(
                        margin: const EdgeInsets.only(top: 3, bottom: 2),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: ThixPolicy.danger.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: ThixPolicy.danger.withOpacity(0.35)),
                        ),
                        child: Row(children: [
                          if (escalationPending) ...[const PulseDot(color: ThixPolicy.danger, size: 8), const SizedBox(width: 6)],
                          const Icon(Icons.swap_vert_rounded, size: 13, color: ThixPolicy.danger),
                          const SizedBox(width: 4),
                          Text(clS(context, 'chatlist_escalated', fb: 'ESCALADE').toUpperCase(),
                              style: ThixPolicy.microStyle.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.danger, letterSpacing: 0.4)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '$agentName  →  $clientName',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textMain, fontWeight: ThixPolicy.semiBold, fontSize: 11.5),
                            ),
                          ),
                        ]),
                      ),
                    const SizedBox(height: 3),
                    Row(children: [
                      ListMessageStatusLights.fromMessage(lastMessage, currentUserId),
                      if (preview.icon != null)
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Icon(preview.icon, size: 14, color: preview.color ?? (unread ? ThixPolicy.textMain : ThixPolicy.textSecondary)),
                        ),
                      Expanded(
                        child: Text.rich(
                          TextSpan(style: baseStyle, children: [
                            if (preview.prefix != null) TextSpan(text: '${preview.prefix} ', style: baseStyle.copyWith(color: ThixPolicy.danger, fontWeight: ThixPolicy.bold)),
                            TextSpan(text: preview.text.isEmpty ? '—' : preview.text),
                          ]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (unread)
                        Container(
                          margin: const EdgeInsets.only(left: 10),
                          constraints: const BoxConstraints(minWidth: 22),
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(color: muted ? ThixPolicy.textMuted : kInk, borderRadius: BorderRadius.circular(12)),
                          alignment: Alignment.center,
                          child: Text(conv.unreadCount > 99 ? '99+' : '${conv.unreadCount}', style: ThixPolicy.microStyle.copyWith(color: Colors.white, fontWeight: ThixPolicy.bold)),
                        ),
                    ]),
                  ]),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _NameRow extends ConsumerWidget {
  final ChatConversation conv;
  final String chatName;
  final String otherUserId;
  final bool unread;
  final bool muted;
  const _NameRow({required this.conv, required this.chatName, required this.otherUserId, required this.unread, required this.muted});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    CertificationTier? tier;
    CertificationStatus? status;
    bool isCertified = false;
    bool isLegacyVerified = false;
    if (!conv.isGroup && !conv.isEscalation && otherUserId.isNotEmpty) {
      final pd = ref.watch(userProfileProvider(otherUserId)).valueOrNull;
      if (pd != null) {
        tier = CertificationTierX.parse(pd['certification_tier']);
        status = CertificationStatusX.parse(pd['certification_status']);
        isCertified = status == CertificationStatus.approved || status == CertificationStatus.generated;
        isLegacyVerified = pd['is_verified'] == true;
      }
    }
    return Row(children: [
      Flexible(
        child: Text(
          chatName.isEmpty ? clS(context, 'chatlist_unknown') : chatName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: ThixPolicy.titleStyle.copyWith(fontSize: 15, fontWeight: unread ? ThixPolicy.bold : ThixPolicy.semiBold, color: ThixPolicy.textMain),
        ),
      ),
      if (isCertified)
        CertificationNameBadge(tier: tier, status: status, showLabel: false, iconSize: 15, padding: const EdgeInsets.only(left: 4))
      else if (isLegacyVerified)
        const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.verified_rounded, color: ThixPolicy.gold, size: 15)),
      if (conv.isGroup && !conv.isEscalation) ...[const SizedBox(width: 4), const Icon(Icons.groups_rounded, size: 14, color: ThixPolicy.textSecondary)],
      if (conv.isPinned) ...[const SizedBox(width: 4), const Icon(Icons.push_pin_rounded, size: 14, color: ThixPolicy.gold)],
      if (muted) ...[const SizedBox(width: 4), const Icon(Icons.volume_off_rounded, size: 14, color: ThixPolicy.warning)],
      if (conv.isLocked) ...[const SizedBox(width: 4), const Icon(Icons.lock_rounded, size: 14, color: ThixPolicy.danger)],
    ]);
  }
}

// ============================================================================
// 🧭 BARRE DU BAS : icônes + libellés + point actif + pastilles numérotées
// ============================================================================
class ChatBottomNav extends StatelessWidget {
  final int selected;
  final int networkBadge;
  final int chatBadge;
  final int callsBadge;
  final ValueChanged<int> onTap;
  final VoidCallback onCreate;
  final VoidCallback onDoubleTapChats;

  const ChatBottomNav({
    super.key,
    required this.selected,
    required this.networkBadge,
    required this.chatBadge,
    required this.callsBadge,
    required this.onTap,
    required this.onCreate,
    required this.onDoubleTapChats,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ThixPolicy.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: ThixPolicy.border.withOpacity(0.8))),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 14, offset: const Offset(0, -3))],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 66,
          child: Row(children: [
            _item(context, Icons.people_alt_outlined, Icons.people_alt_rounded, clS(context, 'chatlist_network'), 0, networkBadge),
            _item(context, Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded, clS(context, 'chatlist_discussions'), 1, chatBadge, onDouble: onDoubleTapChats),
            Expanded(
              child: Semantics(
                button: true,
                label: clS(context, 'chatlist_create_new'),
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    onCreate();
                  },
                  child: Center(
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: kInk,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 10, offset: const Offset(0, 4))],
                      ),
                      child: const Icon(Icons.edit_rounded, color: Colors.white, size: 22),
                    ),
                  ),
                ),
              ),
            ),
            _item(context, Icons.call_outlined, Icons.call_rounded, clS(context, 'chatlist_calls'), 2, callsBadge),
            _item(context, Icons.settings_outlined, Icons.settings_rounded, clS(context, 'chatlist_settings'), 3, 0),
          ]),
        ),
      ),
    );
  }

  Widget _item(BuildContext context, IconData off, IconData on, String label, int idx, int badge, {VoidCallback? onDouble}) {
    final sel = selected == idx;
    final color = sel ? kInk : ThixPolicy.textSecondary.withOpacity(0.7);
    return Expanded(
      child: Semantics(
        button: true,
        selected: sel,
        label: badge > 0 ? '$label ($badge)' : label,
        child: InkWell(
          onTap: () => onTap(idx),
          onDoubleTap: onDouble,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Stack(clipBehavior: Clip.none, children: [
              AnimatedScale(
                scale: sel ? 1.12 : 1.0,
                duration: const Duration(milliseconds: 180),
                child: Icon(sel ? on : off, color: color, size: 25),
              ),
              if (badge > 0)
                Positioned(
                  right: -9,
                  top: -6,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(color: ThixPolicy.danger, borderRadius: BorderRadius.circular(9), border: Border.all(color: Colors.white, width: 1.5)),
                    child: Text(badge > 99 ? '99+' : '$badge', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                  ),
                ),
            ]),
            const SizedBox(height: 3),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, fontWeight: sel ? FontWeight.w800 : FontWeight.w600, color: color)),
            const SizedBox(height: 3),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: sel ? 5 : 0,
              height: sel ? 5 : 0,
              decoration: const BoxDecoration(color: kInk, shape: BoxShape.circle),
            ),
          ]),
        ),
      ),
    );
  }
}
