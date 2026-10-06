// lib/presentation/chat/chat_list_page.dart
//
// ChatListPage — v2 (enterprise)
// ✅ Non lus : tuile surlignée, nom/aperçu en gras, heure bleue, pastille (grise si muet)
// ✅ Escalades : DEUX profils (client + agent), DEUX barres côte à côte, pulse si non acceptée
// ✅ Appels : aperçu entrant / sortant / manqué (rouge) dans la liste ; badges onglets
//    Appels + Réseau + cloche, conservés jusqu'à l'ouverture
// ✅ Brouillons visibles dans la liste (« Brouillon : … » en rouge)
// ✅ Conversation verrouillée : aperçu masqué, retrait du verrou protégé par mot de passe
// ✅ Vault : mot de passe salé + hashé (SHA-256 itéré), anti-force-brute (5 essais → 30 s),
//    migration automatique de l'ancien stockage base64
// ✅ i18n : toutes les clés conservées, repli EN/FR selon la langue (map _kFb)
// ✅ Swipe : archiver avec ANNULER, désactivé en mode sélection
// ✅ Recherche avec debounce, bloc-notes sans fuite mémoire, erreurs gérées partout
//
// ⚠️ Dépendance : `crypto` (pubspec.yaml → crypto: ^3.0.3)

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/features/auth/presentation/providers/auth_controller.dart';
import 'package:thix_id/features/network/presentation/providers/user_profile_providers.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/models/certification_tier.dart';
import 'package:thix_id/models/chat/chat_conversation.dart';
import 'package:thix_id/models/chat/chat_message.dart';
import 'package:thix_id/presentation/certification/widgets/certification_name_badge.dart';
import 'package:thix_id/presentation/chat/call/call_history_page.dart';
import 'package:thix_id/presentation/chat/providers/chat_list_provider.dart';
import 'package:thix_id/presentation/chat/providers/chat_notification_counters_provider.dart';
import 'package:thix_id/presentation/chat/providers/presence_provider.dart';
import 'package:thix_id/presentation/chat/providers/status_provider.dart';
import 'package:thix_id/presentation/chat/screens/group_create_page.dart';
import 'package:thix_id/presentation/chat/settings/chat_settings_page.dart';
import 'package:thix_id/presentation/chat/widgets/status_story_row.dart';
import 'package:thix_id/services/biometric_service.dart';

import 'chat_screen.dart';
import 'new_conversation_page.dart';

// ============================================================================
// CONSTANTS
// ============================================================================
const int _kLoadMoreThresholdPx = 300;
const int _kLoadMoreThrottleMs = 500;
const int _kSearchDebounceMs = 300;
const int _kMaxChatNameLength = 80;
const int _kMaxPreviewLength = 140;
const int _kMaxPinned = 3;
const int _kMaxLockAttempts = 5;
const int _kLockCooldownSeconds = 30;
const int _kPwdIterations = 5000;
const String _kLockPwdKey = 'thix_chat_lock_pwd_v1';
const String _kNotesKey = 'thix_chat_notes_v1';
// ⚠️ Doit rester identique à _kDraftPrefix de chat_screen.dart
const String _kDraftPrefix = 'thix_chat_draft_v1_';

// ============================================================================
// i18n : clé l10n d'abord, sinon repli [EN, FR] selon la langue de l'app
// ============================================================================
const Map<String, List<String>> _kFb = {
  'chatlist_lock_define_title': ['Set a password', 'Définir un mot de passe'],
  'chatlist_lock_define_sub': ['This password opens your locked chats.', 'Ce mot de passe ouvrira vos conversations verrouillées.'],
  'chatlist_lock_pwd': ['Password', 'Mot de passe'],
  'chatlist_lock_pwd_confirm': ['Confirm', 'Confirmer'],
  'chatlist_lock_weak': ['Password too weak (8+ chars, upper, lower, digit)', 'Mot de passe trop faible (8+ car., maj., min., chiffre)'],
  'chatlist_lock_mismatch': ['Passwords do not match', 'Les mots de passe ne correspondent pas'],
  'chatlist_lock_save': ['Save', 'Enregistrer'],
  'chatlist_locked_title': ['Locked chat', 'Conversation verrouillée'],
  'chatlist_biometric_reason': ['Open {0}', 'Ouvrir {0}'],
  'chatlist_use_biometric': ['Biometrics', 'Biométrie'],
  'chatlist_lock_bad_pwd': ['Wrong password', 'Mot de passe incorrect'],
  'chatlist_lock_cooldown': ['Too many attempts. Try again in {0}s', 'Trop de tentatives. Réessayez dans {0}s'],
  'chatlist_unlock_open': ['Open', 'Ouvrir'],
  'chatlist_locked_denied': ['Access denied', 'Accès refusé'],
  'chatlist_locked_preview': ['Locked chat', 'Conversation verrouillée'],
  'chatlist_notebook': ['My notebook', 'Mon bloc-notes'],
  'chatlist_notebook_hint': ['Write your private notes…', 'Écrivez vos notes privées…'],
  'chatlist_notebook_saved': ['Notes saved', 'Notes enregistrées'],
  'chatlist_notebook_save': ['Save', 'Enregistrer'],
  'chatlist_nothing_unread': ['No unread messages', 'Aucun message non lu'],
  'chatlist_all_read': ['All marked as read', 'Tout est marqué comme lu'],
  'chatlist_notifications': ['Notifications', 'Notifications'],
  'chatlist_pending_escalations': ['Pending escalations', 'Escalades en attente'],
  'chatlist_requires_action': ['Action required', 'Action requise'],
  'chatlist_mark_all_read': ['Mark all as read', 'Tout marquer comme lu'],
  'chatlist_unread_label': ['unread', 'non lus'],
  'chatlist_no_recent': ['No recent notifications', 'Aucune notification récente'],
  'chatlist_missed_calls': ['{0} missed call(s)', '{0} appel(s) manqué(s)'],
  'chatlist_new_connections': ['{0} new connection(s)', '{0} nouvelle(s) connexion(s)'],
  'chatlist_tap_to_view': ['Tap to view', 'Appuyez pour voir'],
  'chatlist_new_discussion': ['New discussion', 'Nouvelle discussion'],
  'chatlist_start_private': ['Start a private chat', 'Démarrer une conversation privée'],
  'chatlist_create_group': ['Create a group', 'Créer un groupe'],
  'chatlist_collaborate_team': ['Collaborate with your team', 'Collaborez avec votre équipe'],
  'chatlist_draft_prefix': ['Draft:', 'Brouillon :'],
  'chatlist_new_conversation': ['New conversation', 'Nouvelle conversation'],
  'chatlist_protected_message': ['Protected message', 'Message protégé'],
  'chatlist_photo': ['Photo', 'Photo'],
  'chatlist_video': ['Video', 'Vidéo'],
  'chatlist_audio_message': ['Voice message', 'Message vocal'],
  'chatlist_sticker': ['Sticker', 'Sticker'],
  'chatlist_msg_deleted': ['This message was deleted', 'Ce message a été supprimé'],
  'chatlist_msg_expired': ['Message disappeared', 'Message disparu'],
  'chatlist_call_missed': ['Missed call', 'Appel manqué'],
  'chatlist_call_missed_video': ['Missed video call', 'Appel vidéo manqué'],
  'chatlist_call_outgoing': ['Outgoing call', 'Appel sortant'],
  'chatlist_call_incoming': ['Incoming call', 'Appel entrant'],
  'chatlist_unpin': ['Unpin', 'Désépingler'],
  'chatlist_pin': ['Pin', 'Épingler'],
  'chatlist_unpin_subtitle': ['Remove from the top', 'Retirer du haut de la liste'],
  'chatlist_pin_subtitle': ['Keep at the top (max {0})', 'Garder en haut (max {0})'],
  'chatlist_unarchive': ['Unarchive', 'Désarchiver'],
  'chatlist_archive': ['Archive', 'Archiver'],
  'chatlist_unarchive_subtitle': ['Move back to your chats', 'Remettre dans vos conversations'],
  'chatlist_archive_subtitle': ['Hide from the main list', 'Masquer de la liste principale'],
  'chatlist_unmute': ['Unmute', 'Réactiver le son'],
  'chatlist_mute': ['Mute', 'Sourdine'],
  'chatlist_mute_remaining': ['Muted · {0} left', 'Muet · reste {0}'],
  'chatlist_mute_choose': ['Choose a duration', 'Choisir une durée'],
  'chatlist_unlock': ['Remove lock', 'Retirer le verrou'],
  'chatlist_lock': ['Lock', 'Verrouiller'],
  'chatlist_unlock_subtitle': ['Password required to remove it', 'Mot de passe requis pour le retirer'],
  'chatlist_lock_subtitle_pwd': ['Protect with a password when opening', 'Protéger par mot de passe à l’ouverture'],
  'chatlist_lock_confirm_title': ['Lock this chat?', 'Verrouiller cette conversation ?'],
  'chatlist_lock_confirm_message_pwd': ['A password (or biometrics) will be required to open this chat.', 'Un mot de passe (ou la biométrie) sera exigé pour ouvrir cette conversation.'],
  'chatlist_mark_unread': ['Mark as unread', 'Marquer comme non lu'],
  'chatlist_mark_unread_subtitle': ['Show it as unread again', 'La remettre en non lu'],
  'chatlist_delete': ['Delete', 'Supprimer'],
  'chatlist_delete_subtitle': ['Remove this chat from your list', 'Retirer cette conversation de votre liste'],
  'chatlist_mute_title': ['Mute notifications', 'Mettre en sourdine'],
  'chatlist_mute_8h': ['8 hours', '8 heures'],
  'chatlist_mute_1w': ['1 week', '1 semaine'],
  'chatlist_mute_forever': ['Always', 'Toujours'],
  'chatlist_muted_success': ['Chat muted', 'Conversation mise en sourdine'],
  'chatlist_delete_title': ['Delete chat?', 'Supprimer la conversation ?'],
  'chatlist_delete_message': ['This action cannot be undone.', 'Cette action est irréversible.'],
  'common_delete': ['Delete', 'Supprimer'],
  'common_cancel': ['Cancel', 'Annuler'],
  'common_clear': ['Clear', 'Effacer'],
  'chatlist_deleted': ['Chat deleted', 'Conversation supprimée'],
  'chatlist_selected_count': ['{0} selected', '{0} sélectionnée(s)'],
  'chatlist_bulk_archived': ['Chats archived', 'Conversations archivées'],
  'chatlist_mark_read': ['Mark as read', 'Marquer comme lu'],
  'chatlist_bulk_marked_read': ['Marked as read', 'Marquées comme lues'],
  'chatlist_bulk_delete_confirm': ['Delete {0} chat(s)?', 'Supprimer {0} conversation(s) ?'],
  'chatlist_bulk_deleted': ['Chats deleted', 'Conversations supprimées'],
  'chatlist_escalations': ['Escalations', 'Escalades'],
  'chatlist_online': ['online', 'en ligne'],
  'chatlist_search_label': ['Search chats', 'Rechercher des conversations'],
  'chatlist_search_hint': ['Search conversation', 'Rechercher une conversation'],
  'chatlist_no_results': ['No results', 'Aucun résultat'],
  'chatlist_filter_all': ['All', 'Tous'],
  'chatlist_filter_unread': ['Unread', 'Non lus'],
  'chatlist_filter_teams': ['Teams', 'Équipes'],
  'chatlist_filter_personal': ['Personal', 'Personnel'],
  'chatlist_filter_pinned': ['Pinned', 'Épinglés'],
  'chatlist_filter_archived': ['Archived', 'Archivés'],
  'chatlist_no_archived': ['No archived chats', 'Aucune conversation archivée'],
  'chatlist_no_conversation': ['No conversations yet', 'Aucune conversation'],
  'chatlist_group_thix': ['THIX group', 'Groupe THIX'],
  'chatlist_contact_thix': ['THIX contact', 'Contact THIX'],
  'chatlist_unarchived': ['Chat unarchived', 'Conversation désarchivée'],
  'chatlist_archived': ['Chat archived', 'Conversation archivée'],
  'chatlist_marked_read': ['Marked as read', 'Marqué comme lu'],
  'chatlist_marked_unread': ['Marked as unread', 'Marqué comme non lu'],
  'chatlist_undo': ['Undo', 'Annuler'],
  'chatlist_network': ['Network', 'Réseau'],
  'chatlist_discussions': ['Chats', 'Discussions'],
  'chatlist_create_new': ['Create', 'Créer'],
  'chatlist_calls': ['Calls', 'Appels'],
  'chatlist_settings': ['Settings', 'Paramètres'],
  'chatlist_yesterday': ['Yesterday', 'Hier'],
  'chatlist_unknown': ['Unknown', 'Inconnu'],
  'chatlist_escalated': ['Escalated', 'Escaladé'],
  'chatlist_agent': ['Agent', 'Agent'],
  'chatlist_agent_label': ['Agent', 'Agent'],
  'chatlist_client_label': ['Client', 'Client'],
  'chatlist_err_timeout': ['Request timed out.', 'Délai dépassé.'],
  'chatlist_err_network': ['Network error.', 'Erreur réseau.'],
  'chatlist_err_denied': ['Access denied.', 'Accès non autorisé.'],
  'chatlist_err_generic': ['Something went wrong.', 'Une erreur est survenue.'],
};

String _s(BuildContext ctx, String key, {List<String>? args}) {
  final l10n = AppLocalizations.of(ctx);
  var out = args == null ? l10n.t(key) : l10n.t(key, args: args);
  if (out.isNotEmpty && out != key) return out;
  final fb = _kFb[key];
  if (fb == null) return key;
  final fr = Localizations.localeOf(ctx).languageCode == 'fr';
  out = fr ? fb[1] : fb[0];
  if (args != null) {
    for (var i = 0; i < args.length; i++) {
      out = out.replaceAll('{$i}', args[i]);
    }
  }
  return out;
}

// ============================================================================
// VALIDATORS
// ============================================================================
class _ListValidators {
  _ListValidators._();

  static final RegExp _ctrlKeepNl = RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]');
  static final RegExp _ctrlAll = RegExp(r'[\x00-\x1F\x7F]');
  static final RegExp _bidi = RegExp(r'[\u200B\u200E\u200F\u202A-\u202E\u2066-\u2069\uFEFF]');
  static final RegExp _tags = RegExp(r'<[a-zA-Z/!?][^>]*>');
  static final RegExp _jsScheme = RegExp(r'(javascript|vbscript)\s*:', caseSensitive: false);

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
    if (singleLine) s = s.replaceAll(RegExp(r'\s+'), ' ');
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
    if (t.length > 20 &&
        !t.contains(' ') &&
        RegExp(r'^[A-Za-z0-9+/=]+$').hasMatch(t.replaceFirst(RegExp(r'^ENCv1:'), ''))) {
      return true;
    }
    return false;
  }

  static bool isImageFile(String? name) {
    if (name == null) return false;
    final l = name.toLowerCase();
    return l.endsWith('.jpg') || l.endsWith('.jpeg') || l.endsWith('.png') || l.endsWith('.gif') || l.endsWith('.webp');
  }

  static bool isVideoFile(String? name) {
    if (name == null) return false;
    final l = name.toLowerCase();
    return l.endsWith('.mp4') || l.endsWith('.mov') || l.endsWith('.avi');
  }

  static bool isAudioFile(String? name) {
    if (name == null) return false;
    final l = name.toLowerCase();
    return l.endsWith('.mp3') || l.endsWith('.wav') || l.endsWith('.m4a') || name.contains('Message audio (');
  }

  static int passwordScore(String pwd) {
    int score = 0;
    if (pwd.length >= 8) score++;
    if (pwd.length >= 12) score++;
    if (pwd.contains(RegExp(r'[a-z]')) && pwd.contains(RegExp(r'[A-Z]'))) score++;
    if (pwd.contains(RegExp(r'[0-9]'))) score++;
    if (pwd.contains(RegExp(r'[^\w\s]'))) score++;
    return score;
  }
}

// ============================================================================
// 🔒 VAULT LOCAL : mot de passe salé + hashé, anti-force-brute
// Format stocké : v2:<sel base64>:<hash base64>
// L'ancien format (base64 du mot de passe) est vérifié puis migré automatiquement.
// ============================================================================
class _LockVault {
  _LockVault._();

  static int _fails = 0;
  static DateTime? _lockedUntil;

  /// Secondes restantes avant de pouvoir réessayer (0 = libre).
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

  static Future<String?> _read() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kLockPwdKey);
  }

  static Future<bool> hasPassword() async => (await _read()) != null;

  static List<int> _derive(List<int> salt, String pwd) {
    final pb = utf8.encode(pwd);
    var h = sha256.convert([...salt, ...pb]).bytes;
    for (var i = 0; i < _kPwdIterations; i++) {
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
    await prefs.setString(_kLockPwdKey, 'v2:${base64Encode(salt)}:${base64Encode(hash)}');
  }

  static Future<bool> verify(String pwd) async {
    if (cooldownRemaining > 0) return false;
    final stored = await _read();
    if (stored == null) return false;
    var ok = false;
    try {
      if (stored.startsWith('v2:')) {
        final p = stored.split(':');
        if (p.length == 3) {
          ok = _constEq(_derive(base64Decode(p[1]), pwd), base64Decode(p[2]));
        }
      } else {
        // Ancien format : vérification puis migration vers le hash salé
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
      if (_fails >= _kMaxLockAttempts) {
        _lockedUntil = DateTime.now().add(const Duration(seconds: _kLockCooldownSeconds));
      }
    }
    return ok;
  }
}

// ============================================================================
// DIALOGUES (widgets dédiés : contrôleurs correctement libérés)
// ============================================================================
class _DefinePasswordDialog extends StatefulWidget {
  const _DefinePasswordDialog();

  @override
  State<_DefinePasswordDialog> createState() => _DefinePasswordDialogState();
}

class _DefinePasswordDialogState extends State<_DefinePasswordDialog> {
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
    if (_ListValidators.passwordScore(_pass.text) < 3) {
      setState(() => _error = _s(context, 'chatlist_lock_weak'));
      return;
    }
    if (_pass.text != _confirm.text) {
      setState(() => _error = _s(context, 'chatlist_lock_mismatch'));
      return;
    }
    setState(() => _saving = true);
    await _LockVault.setPassword(_pass.text);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final score = _ListValidators.passwordScore(_pass.text);
    return AlertDialog(
      backgroundColor: ThixPolicy.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rLg)),
      title: Row(
        children: [
          const Icon(Icons.lock_outline_rounded, color: ThixPolicy.danger, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(_s(context, 'chatlist_lock_define_title'),
                style: ThixPolicy.titleStyle.copyWith(fontWeight: ThixPolicy.bold, fontSize: 16)),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_s(context, 'chatlist_lock_define_sub'),
                style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textSecondary)),
            const SizedBox(height: 12),
            TextField(
              controller: _pass,
              obscureText: true,
              onChanged: (_) => setState(() => _error = null),
              decoration: InputDecoration(labelText: _s(context, 'chatlist_lock_pwd')),
            ),
            const SizedBox(height: 6),
            Row(
              children: List.generate(
                5,
                (i) => Expanded(
                  child: Container(
                    height: 4,
                    margin: const EdgeInsets.only(right: 3),
                    decoration: BoxDecoration(
                      color: i < score ? (score >= 3 ? ThixPolicy.success : ThixPolicy.warning) : ThixPolicy.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _confirm,
              obscureText: true,
              onChanged: (_) => setState(() => _error = null),
              decoration: InputDecoration(labelText: _s(context, 'chatlist_lock_pwd_confirm')),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!, style: const TextStyle(color: ThixPolicy.danger, fontSize: 12)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(_s(context, 'common_cancel'))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.primary),
          onPressed: _saving ? null : _save,
          child: Text(_s(context, 'chatlist_lock_save'), style: const TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

class _UnlockDialog extends StatefulWidget {
  final String name;
  final bool bioAvailable;
  const _UnlockDialog({required this.name, required this.bioAvailable});

  @override
  State<_UnlockDialog> createState() => _UnlockDialogState();
}

class _UnlockDialogState extends State<_UnlockDialog> {
  final _ctrl = TextEditingController();
  String? _error;
  bool _busy = false;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    if (_LockVault.cooldownRemaining > 0) _startTick();
  }

  void _startTick() {
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_LockVault.cooldownRemaining <= 0) {
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
    if (_busy || _LockVault.cooldownRemaining > 0) return;
    setState(() => _busy = true);
    final ok = await _LockVault.verify(_ctrl.text);
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, true);
      return;
    }
    setState(() {
      _busy = false;
      _error = _s(context, 'chatlist_lock_bad_pwd');
    });
    if (_LockVault.cooldownRemaining > 0) _startTick();
  }

  Future<void> _bio() async {
    try {
      final ok = await BiometricService.instance.authenticate(
        reason: _s(context, 'chatlist_biometric_reason', args: [widget.name]),
      );
      if (mounted && ok == true) Navigator.pop(context, true);
    } catch (e) {
      debugPrint('[ChatList] ⚠️ Biometric error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cd = _LockVault.cooldownRemaining;
    final msg = cd > 0 ? _s(context, 'chatlist_lock_cooldown', args: ['$cd']) : _error;
    return AlertDialog(
      backgroundColor: ThixPolicy.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rLg)),
      title: Row(
        children: [
          const Icon(Icons.lock_rounded, color: ThixPolicy.danger, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(_s(context, 'chatlist_locked_title'),
                style: ThixPolicy.titleStyle.copyWith(fontWeight: ThixPolicy.bold, fontSize: 16)),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.name, style: ThixPolicy.bodyStyle.copyWith(fontWeight: ThixPolicy.semiBold)),
          const SizedBox(height: 12),
          TextField(
            controller: _ctrl,
            obscureText: true,
            autofocus: true,
            enabled: cd == 0,
            onChanged: (_) => setState(() => _error = null),
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(labelText: _s(context, 'chatlist_lock_pwd')),
          ),
          if (msg != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(msg, style: const TextStyle(color: ThixPolicy.danger, fontSize: 12)),
            ),
        ],
      ),
      actions: [
        if (widget.bioAvailable)
          TextButton(
            onPressed: _bio,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.fingerprint_rounded, size: 18),
                const SizedBox(width: 6),
                Text(_s(context, 'chatlist_use_biometric')),
              ],
            ),
          ),
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(_s(context, 'common_cancel'))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.primary),
          onPressed: (_busy || cd > 0) ? null : _submit,
          child: Text(_s(context, 'chatlist_unlock_open'), style: const TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

// ============================================================================
// 📓 BLOC-NOTES (sauvegarde auto, même si on ferme en glissant)
// ============================================================================
class _NotebookSheet extends StatefulWidget {
  final SharedPreferences prefs;
  const _NotebookSheet({required this.prefs});

  @override
  State<_NotebookSheet> createState() => _NotebookSheetState();
}

class _NotebookSheetState extends State<_NotebookSheet> {
  late final TextEditingController _ctrl = TextEditingController(text: widget.prefs.getString(_kNotesKey) ?? '');
  Timer? _debounce;
  late int _len = _ctrl.text.length;

  @override
  void dispose() {
    _debounce?.cancel();
    unawaited(widget.prefs.setString(_kNotesKey, _ctrl.text));
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    setState(() => _len = v.length);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 700), () {
      unawaited(widget.prefs.setString(_kNotesKey, v));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: BoxDecoration(
          color: ThixPolicy.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: ThixPolicy.border, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.menu_book_outlined, color: ThixPolicy.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_s(context, 'chatlist_notebook'),
                      style: ThixPolicy.titleStyle.copyWith(fontWeight: ThixPolicy.bold)),
                ),
                Text('$_len', style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textMuted)),
              ],
            ),
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
                  hintText: _s(context, 'chatlist_notebook_hint'),
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: ThixPolicy.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () => Navigator.pop(context, true),
                child: Text(_s(context, 'chatlist_notebook_save'), style: const TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// APERÇU DE LA DERNIÈRE ACTIVITÉ
// ============================================================================
class _Preview {
  final String text;
  final String? prefix; // ex. « Brouillon : » (rouge)
  final IconData? icon;
  final Color? color;
  final bool strong;
  const _Preview(this.text, {this.prefix, this.icon, this.color, this.strong = false});
}

// ============================================================================
// PAGE
// ============================================================================
class ChatListPage extends ConsumerStatefulWidget {
  const ChatListPage({super.key});

  @override
  ConsumerState<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends ConsumerState<ChatListPage> with WidgetsBindingObserver {
  final _searchCtrl = TextEditingController();
  final _scroll = ScrollController();
  final Map<String, String> _drafts = <String, String>{};
  int _selectedNav = 1;
  DateTime? _lastLoadMore;
  Timer? _searchDebounce;

  static const List<String> _filterKeys = ['all', 'unread', 'teams', 'personal', 'pinned', 'archived'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scroll.addListener(_onScroll);
    unawaited(_loadDrafts());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scroll.removeListener(_onScroll);
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.pixels > _scroll.position.maxScrollExtent - _kLoadMoreThresholdPx) {
      final now = DateTime.now();
      if (_lastLoadMore != null && now.difference(_lastLoadMore!).inMilliseconds < _kLoadMoreThrottleMs) return;
      _lastLoadMore = now;
      ref.read(chatListProvider.notifier).loadMore();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshAllCounters();
  }

  void _refreshAllCounters() {
    unawaited(ref.read(notificationCountersProvider.notifier).refresh()
        .catchError((e) => debugPrint('[ChatList] ⚠️ Counters refresh error: $e')));
    unawaited(ref.read(chatListProvider.notifier).refresh(silent: true)
        .catchError((e) => debugPrint('[ChatList] ⚠️ List refresh error: $e')));
    unawaited(ref.read(statusProvider.notifier).refresh().catchError((_) {}));
    unawaited(_loadDrafts());
  }

  /// Charge les brouillons enregistrés par ChatScreen (par conversation).
  Future<void> _loadDrafts() async {
    final uid = ref.read(authControllerProvider).value?.id ?? '';
    if (uid.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final prefix = '$_kDraftPrefix${uid}_';
      final map = <String, String>{};
      for (final k in prefs.getKeys()) {
        if (!k.startsWith(prefix)) continue;
        final v = prefs.getString(k);
        if (v != null && v.trim().isNotEmpty) map[k.substring(prefix.length)] = v;
      }
      if (!mounted) return;
      setState(() {
        _drafts
          ..clear()
          ..addAll(map);
      });
    } catch (e) {
      debugPrint('[ChatList] ⚠️ loadDrafts: $e');
    }
  }

  String _errMsg(Object e) {
    final m = e.toString().toLowerCase();
    if (m.contains('timeout')) return _s(context, 'chatlist_err_timeout');
    if (m.contains('network') || m.contains('socket')) return _s(context, 'chatlist_err_network');
    if (m.contains('permission') || m.contains('policy')) return _s(context, 'chatlist_err_denied');
    return _s(context, 'chatlist_err_generic');
  }

  Future<void> _guard(FutureOr<void> Function() fn) async {
    try {
      await fn();
    } catch (e) {
      debugPrint('[ChatList] ❌ action error: $e');
      _showError(_errMsg(e));
    }
  }

  // ==========================================================================
  // 🔒 LOCK
  // ==========================================================================
  Future<bool> _defineLockPassword() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => const _DefinePasswordDialog(),
    );
    return ok == true;
  }

  Future<bool> _promptUnlock(ChatConversation conv) async {
    var bio = false;
    try {
      bio = await BiometricService.instance.isAvailable();
    } catch (_) {}
    if (!mounted) return false;
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _UnlockDialog(
        name: _ListValidators.sanitize(conv.displayName, maxLength: 40),
        bioAvailable: bio,
      ),
    );
    return ok == true;
  }

  // ── OUVERTURE DE CONVERSATION ──
  // Le « marquer comme lu » est fait par ChatScreen APRÈS avoir mémorisé le nombre
  // de non-lus : le bouton « premiers messages non lus » fonctionne ainsi.
  Future<void> _openConversation(ChatConversation conv) async {
    HapticFeedback.mediumImpact();

    if (conv.isLocked) {
      final unlocked = await _promptUnlock(conv);
      if (!unlocked) {
        _showInfo(_s(context, 'chatlist_locked_denied'));
        return;
      }
    }
    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ChatScreen(conversationId: conv.id, conversation: conv)),
    );

    if (!mounted) return;
    _refreshAllCounters();
    // le brouillon est écrit en arrière-plan à la fermeture de l'écran
    unawaited(Future.delayed(const Duration(milliseconds: 350), _loadDrafts));
  }

  // ==========================================================================
  // 📓 NOTEBOOK
  // ==========================================================================
  Future<void> _openNotebook() async {
    HapticFeedback.selectionClick();
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      final saved = await showModalBottomSheet<bool>(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (_) => _NotebookSheet(prefs: prefs),
      );
      if (saved == true) _showSuccess(_s(context, 'chatlist_notebook_saved'));
    } catch (e) {
      _showError(_errMsg(e));
    }
  }

  // ==========================================================================
  // NAVIGATION
  // ==========================================================================
  void _navigateTo(int idx) {
    HapticFeedback.lightImpact();
    final countersNotifier = ref.read(notificationCountersProvider.notifier);

    switch (idx) {
      case 0:
        // Le badge reste affiché jusqu'à l'ouverture de l'écran (comme WhatsApp)
        countersNotifier.clearNewConnections();
        context.pushNamed('connections').then((_) {
          if (mounted) _refreshAllCounters();
        });
        break;
      case 1:
        setState(() => _selectedNav = idx);
        break;
      case 2:
        countersNotifier.clearMissedCalls();
        Navigator.push(context, MaterialPageRoute(builder: (_) => const CallHistoryPage())).then((_) {
          if (mounted) _refreshAllCounters();
        });
        break;
      case 3:
        Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatSettingsPage())).then((_) {
          if (mounted) _refreshAllCounters();
        });
        break;
    }
  }

  void _goToHomepage() => context.go('/');

  Future<void> _markAllAsRead() async {
    final convs = ref.read(chatListProvider).all.where((c) => c.unreadCount > 0).take(30).toList();
    if (convs.isEmpty) {
      _showInfo(_s(context, 'chatlist_nothing_unread'));
      return;
    }
    await _guard(() async {
      for (final c in convs) {
        await ref.read(chatListProvider.notifier).markAsRead(c.id);
      }
    });
    _showSuccess(_s(context, 'chatlist_all_read'));
  }

  Widget _notifTile(
    BuildContext ctx, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      label: title,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s24, vertical: ThixPolicy.s12),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(ThixPolicy.rMd)),
          child: Icon(icon, color: color, size: 24),
        ),
        title: Text(title, style: ThixPolicy.titleStyle.copyWith(fontWeight: ThixPolicy.bold, fontSize: 15)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Text(subtitle, style: ThixPolicy.bodySmallStyle),
        ),
        trailing: const Icon(Icons.chevron_right_rounded, color: ThixPolicy.textSecondary),
        onTap: onTap,
      ),
    );
  }

  void _openNotifications(int pending, NotificationCounters counters) {
    HapticFeedback.selectionClick();
    final totalUnread = ref.read(chatListProvider).totalUnread;
    final empty = pending == 0 && totalUnread == 0 && counters.missedCalls == 0 && counters.newConnections == 0;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.6),
        decoration: BoxDecoration(
          color: ThixPolicy.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(ThixPolicy.rXl)),
          border: Border(top: BorderSide(color: ThixPolicy.border)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: ThixPolicy.s12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: ThixPolicy.border, borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.fromLTRB(ThixPolicy.s24, ThixPolicy.s20, ThixPolicy.s24, ThixPolicy.s16),
              child: Row(
                children: [
                  const Icon(Icons.notifications_rounded, color: ThixPolicy.textMain, size: 22),
                  const SizedBox(width: ThixPolicy.s12),
                  Text(_s(ctx, 'chatlist_notifications'),
                      style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold, letterSpacing: -0.3)),
                ],
              ),
            ),
            const Divider(height: 1, color: ThixPolicy.border),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  if (pending > 0)
                    _notifTile(ctx,
                        icon: Icons.swap_vert_rounded,
                        color: ThixPolicy.danger,
                        title: _s(ctx, 'chatlist_pending_escalations'),
                        subtitle: _s(ctx, 'chatlist_requires_action'), onTap: () {
                      Navigator.pop(ctx);
                      context.pushNamed('chatEscalationReceived');
                    }),
                  if (counters.missedCalls > 0)
                    _notifTile(ctx,
                        icon: Icons.call_missed_rounded,
                        color: ThixPolicy.danger,
                        title: _s(ctx, 'chatlist_missed_calls', args: ['${counters.missedCalls}']),
                        subtitle: _s(ctx, 'chatlist_tap_to_view'), onTap: () {
                      Navigator.pop(ctx);
                      _navigateTo(2);
                    }),
                  if (counters.newConnections > 0)
                    _notifTile(ctx,
                        icon: Icons.people_alt_rounded,
                        color: ThixPolicy.primary,
                        title: _s(ctx, 'chatlist_new_connections', args: ['${counters.newConnections}']),
                        subtitle: _s(ctx, 'chatlist_tap_to_view'), onTap: () {
                      Navigator.pop(ctx);
                      _navigateTo(0);
                    }),
                  if (totalUnread > 0)
                    _notifTile(ctx,
                        icon: Icons.done_all_rounded,
                        color: ThixPolicy.primary,
                        title: _s(ctx, 'chatlist_mark_all_read'),
                        subtitle: '$totalUnread ${_s(ctx, 'chatlist_unread_label')}', onTap: () {
                      Navigator.pop(ctx);
                      _markAllAsRead();
                    }),
                  if (empty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 48),
                      child: Center(
                        child: Text(_s(ctx, 'chatlist_no_recent'),
                            style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textSecondary)),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: ThixPolicy.s24),
          ],
        ),
      ),
    );
  }

  void _showCreateMenu() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.fromLTRB(ThixPolicy.s20, ThixPolicy.s12, ThixPolicy.s20, ThixPolicy.s32 + MediaQuery.of(ctx).padding.bottom),
        decoration: BoxDecoration(
          color: ThixPolicy.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(ThixPolicy.rXl)),
          border: Border(top: BorderSide(color: ThixPolicy.border)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: ThixPolicy.border, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: ThixPolicy.s24),
            _sheetOpt(
              Icons.chat_bubble_outline_rounded,
              _s(ctx, 'chatlist_new_discussion'),
              _s(ctx, 'chatlist_start_private'),
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NewConversationPage())),
            ),
            const SizedBox(height: ThixPolicy.s12),
            _sheetOpt(
              Icons.group_add_outlined,
              _s(ctx, 'chatlist_create_group'),
              _s(ctx, 'chatlist_collaborate_team'),
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GroupCreatePage())),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sheetOpt(IconData icon, String title, String subtitle, VoidCallback tap) {
    return Semantics(
      button: true,
      label: title,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.pop(context);
            HapticFeedback.selectionClick();
            tap();
          },
          borderRadius: BorderRadius.circular(ThixPolicy.rLg),
          child: Container(
            padding: const EdgeInsets.all(ThixPolicy.s16),
            decoration: BoxDecoration(
              color: ThixPolicy.surfaceSoft,
              border: Border.all(color: ThixPolicy.border),
              borderRadius: BorderRadius.circular(ThixPolicy.rLg),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: ThixPolicy.card,
                    borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                    border: Border.all(color: ThixPolicy.border),
                  ),
                  child: Icon(icon, size: 24, color: ThixPolicy.primaryDeep),
                ),
                const SizedBox(width: ThixPolicy.s16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: ThixPolicy.titleStyle.copyWith(fontSize: 15, fontWeight: ThixPolicy.bold, letterSpacing: -0.2)),
                      const SizedBox(height: 2),
                      Text(subtitle, style: ThixPolicy.bodySmallStyle.copyWith(fontSize: 12, fontWeight: ThixPolicy.medium)),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: ThixPolicy.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // APERÇU : appels (entrant/sortant/manqué), brouillon, médias, verrou…
  // ==========================================================================
  _Preview _buildPreview(ChatConversation conv, String me) {
    final ctx = context;

    // 🔒 Conversation verrouillée : AUCUN contenu dans la liste
    if (conv.isLocked) return _Preview(_s(ctx, 'chatlist_locked_preview'), icon: Icons.lock_rounded);

    // ✍️ Brouillon (local d'abord, sinon celui du serveur)
    final localDraft = _drafts[conv.id];
    final draftRaw = (localDraft != null && localDraft.trim().isNotEmpty) ? localDraft : conv.draft;
    final draft = _ListValidators.sanitize(draftRaw, maxLength: 100, singleLine: true);
    if (draft.isNotEmpty) return _Preview(draft, prefix: _s(ctx, 'chatlist_draft_prefix'));

    final m = conv.lastMessage;
    if (m == null) return _Preview(_s(ctx, 'chatlist_new_conversation'));

    if (m.isDeletedForAll || m.isDeleted) {
      return _Preview(_s(ctx, 'chatlist_msg_deleted'), icon: Icons.block, color: ThixPolicy.textMuted);
    }
    if (m.isExpired) {
      return _Preview(_s(ctx, 'chatlist_msg_expired'), icon: Icons.timer_outlined, color: ThixPolicy.textMuted);
    }

    final type = '${m.mediaType ?? ''}';
    final unread = conv.unreadCount > 0;

    // 📞 Appels
    if (type == 'call_audio' || type == 'call_video') {
      final video = type == 'call_video';
      final low = m.content.toLowerCase();
      final missed = low.contains('manqué') || low.contains('missed') || low.contains('sans réponse');
      if (missed) {
        return _Preview(
          _s(ctx, video ? 'chatlist_call_missed_video' : 'chatlist_call_missed'),
          icon: Icons.call_missed_rounded,
          color: ThixPolicy.danger,
          strong: unread,
        );
      }
      if (m.senderId == me) {
        return _Preview(_s(ctx, 'chatlist_call_outgoing'), icon: Icons.call_made_rounded, color: ThixPolicy.success);
      }
      return _Preview(_s(ctx, 'chatlist_call_incoming'), icon: Icons.call_received_rounded, color: ThixPolicy.primary);
    }

    if (type == 'image') return _Preview(_s(ctx, 'chatlist_photo'), icon: Icons.photo_camera_rounded);
    if (type == 'video') return _Preview(_s(ctx, 'chatlist_video'), icon: Icons.videocam_rounded);
    if (type == 'audio') return _Preview(_s(ctx, 'chatlist_audio_message'), icon: Icons.mic_rounded);
    if (type == 'sticker') return _Preview(_s(ctx, 'chatlist_sticker'), icon: Icons.emoji_emotions_outlined);

    final raw = m.content;
    if (type == 'file') {
      final name = _ListValidators.sanitize(m.mediaName ?? raw, maxLength: 60, singleLine: true);
      return _Preview(name.isEmpty ? '—' : name, icon: Icons.insert_drive_file_rounded);
    }
    if (raw.isEmpty) return _Preview(_s(ctx, 'chatlist_new_conversation'));
    if (_ListValidators.isEncrypted(raw)) return _Preview(_s(ctx, 'chatlist_protected_message'), icon: Icons.lock_rounded);
    if (_ListValidators.isImageFile(raw)) return _Preview(_s(ctx, 'chatlist_photo'), icon: Icons.photo_camera_rounded);
    if (_ListValidators.isVideoFile(raw)) return _Preview(_s(ctx, 'chatlist_video'), icon: Icons.videocam_rounded);
    if (_ListValidators.isAudioFile(raw)) return _Preview(_s(ctx, 'chatlist_audio_message'), icon: Icons.mic_rounded);
    return _Preview(_ListValidators.sanitize(raw, maxLength: _kMaxPreviewLength, singleLine: true));
  }

  bool _isEscalationPending(ChatConversation conv) =>
      conv.isEscalation && (conv.unreadCount > 0 || (conv.escalatedByName?.isNotEmpty ?? false));

  // ── MENU CONTEXTUEL ──
  void _showContextMenu(ChatConversation conv) {
    HapticFeedback.mediumImpact();
    final notifier = ref.read(chatListProvider.notifier);
    final avatar = _ListValidators.sanitizeUrl(conv.displayAvatar);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: EdgeInsets.fromLTRB(ThixPolicy.s20, ThixPolicy.s12, ThixPolicy.s20, ThixPolicy.s32 + MediaQuery.of(ctx).padding.bottom),
        decoration: BoxDecoration(
          color: ThixPolicy.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(ThixPolicy.rXl)),
          border: Border(top: BorderSide(color: ThixPolicy.border)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: ThixPolicy.border, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: ThixPolicy.s20),
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: ThixPolicy.surfaceSoft,
                    backgroundImage: avatar != null ? CachedNetworkImageProvider(avatar) : null,
                    child: avatar == null ? Text(_ListValidators.safeInitial(conv.displayName), style: ThixPolicy.h3Style) : null,
                  ),
                  const SizedBox(width: ThixPolicy.s12),
                  Expanded(
                    child: Text(
                      _ListValidators.sanitize(conv.displayName, maxLength: 40),
                      style: ThixPolicy.titleStyle.copyWith(fontWeight: ThixPolicy.bold, fontSize: 16),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: ThixPolicy.s20),
              const Divider(height: 1),
              const SizedBox(height: ThixPolicy.s8),
              _contextMenuItem(
                icon: conv.isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                label: conv.isPinned ? _s(ctx, 'chatlist_unpin') : _s(ctx, 'chatlist_pin'),
                subtitle: conv.isPinned
                    ? _s(ctx, 'chatlist_unpin_subtitle')
                    : _s(ctx, 'chatlist_pin_subtitle', args: ['$_kMaxPinned']),
                color: ThixPolicy.gold,
                enabled: !conv.isPinned ? ref.read(chatListProvider).canPin : true,
                onTap: () {
                  Navigator.pop(ctx);
                  _guard(() => notifier.togglePin(conv.id));
                },
              ),
              _contextMenuItem(
                icon: conv.isArchived ? Icons.unarchive_rounded : Icons.archive_outlined,
                label: conv.isArchived ? _s(ctx, 'chatlist_unarchive') : _s(ctx, 'chatlist_archive'),
                subtitle: conv.isArchived ? _s(ctx, 'chatlist_unarchive_subtitle') : _s(ctx, 'chatlist_archive_subtitle'),
                color: ThixPolicy.primary,
                onTap: () {
                  Navigator.pop(ctx);
                  _guard(() => notifier.toggleArchive(conv.id));
                },
              ),
              _contextMenuItem(
                icon: conv.isCurrentlyMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                label: conv.isCurrentlyMuted ? _s(ctx, 'chatlist_unmute') : _s(ctx, 'chatlist_mute'),
                subtitle: conv.isCurrentlyMuted
                    ? _s(ctx, 'chatlist_mute_remaining', args: [conv.muteRemainingText])
                    : _s(ctx, 'chatlist_mute_choose'),
                color: conv.isCurrentlyMuted ? ThixPolicy.success : ThixPolicy.warning,
                onTap: () {
                  Navigator.pop(ctx);
                  if (conv.isCurrentlyMuted) {
                    _guard(() => notifier.toggleMute(conv.id));
                  } else {
                    _showMuteDurationPicker(conv.id);
                  }
                },
              ),
              // 🔒 VERROUILLAGE (retirer le verrou exige le mot de passe / la biométrie)
              _contextMenuItem(
                icon: conv.isLocked ? Icons.lock_rounded : Icons.lock_outline_rounded,
                label: conv.isLocked ? _s(ctx, 'chatlist_unlock') : _s(ctx, 'chatlist_lock'),
                subtitle: conv.isLocked ? _s(ctx, 'chatlist_unlock_subtitle') : _s(ctx, 'chatlist_lock_subtitle_pwd'),
                color: ThixPolicy.danger,
                onTap: () async {
                  Navigator.pop(ctx);
                  if (conv.isLocked) {
                    final ok = await _promptUnlock(conv);
                    if (!ok) {
                      _showInfo(_s(context, 'chatlist_locked_denied'));
                      return;
                    }
                    await _guard(() => notifier.toggleLock(conv.id));
                    return;
                  }
                  if (!await _LockVault.hasPassword()) {
                    final defined = await _defineLockPassword();
                    if (!defined) return;
                  }
                  if (!mounted) return;
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (dctx) => AlertDialog(
                      backgroundColor: ThixPolicy.card,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rLg)),
                      title: Text(_s(dctx, 'chatlist_lock_confirm_title'), style: ThixPolicy.titleStyle),
                      content: Text(_s(dctx, 'chatlist_lock_confirm_message_pwd'), style: ThixPolicy.bodyStyle),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(dctx, false), child: Text(_s(dctx, 'common_cancel'))),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.danger),
                          onPressed: () => Navigator.pop(dctx, true),
                          child: Text(_s(dctx, 'chatlist_lock'), style: const TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  );
                  if (confirmed != true) return;
                  await _guard(() => notifier.toggleLock(conv.id));
                },
              ),
              if (conv.unreadCount == 0)
                _contextMenuItem(
                  icon: Icons.mark_unread_chat_alt_rounded,
                  label: _s(ctx, 'chatlist_mark_unread'),
                  subtitle: _s(ctx, 'chatlist_mark_unread_subtitle'),
                  color: ThixPolicy.primary,
                  onTap: () {
                    Navigator.pop(ctx);
                    _guard(() => notifier.markAsUnread(conv.id));
                  },
                ),
              const Divider(height: 1),
              _contextMenuItem(
                icon: Icons.delete_outline_rounded,
                label: _s(ctx, 'chatlist_delete'),
                subtitle: _s(ctx, 'chatlist_delete_subtitle'),
                color: ThixPolicy.danger,
                onTap: () async {
                  Navigator.pop(ctx);
                  await _confirmAndDeleteSingle(conv);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _contextMenuItem({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(ThixPolicy.rMd),
        child: Opacity(
          opacity: enabled ? 1.0 : 0.4,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(ThixPolicy.rMd)),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: ThixPolicy.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                          style: ThixPolicy.titleStyle.copyWith(
                              fontSize: 15, fontWeight: ThixPolicy.bold, color: enabled ? ThixPolicy.textMain : ThixPolicy.textMuted)),
                      const SizedBox(height: 2),
                      Text(subtitle, style: ThixPolicy.captionStyle.copyWith(fontSize: 12, color: ThixPolicy.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showMuteDurationPicker(String convId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.fromLTRB(ThixPolicy.s20, ThixPolicy.s12, ThixPolicy.s20, ThixPolicy.s32 + MediaQuery.of(ctx).padding.bottom),
        decoration: BoxDecoration(
          color: ThixPolicy.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(ThixPolicy.rXl)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: ThixPolicy.border, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: ThixPolicy.s20),
            Text(_s(ctx, 'chatlist_mute_title'), style: ThixPolicy.titleStyle.copyWith(fontWeight: ThixPolicy.bold, fontSize: 16)),
            const SizedBox(height: ThixPolicy.s20),
            _muteOption(ctx, _s(ctx, 'chatlist_mute_8h'), const Duration(hours: 8), convId),
            _muteOption(ctx, _s(ctx, 'chatlist_mute_1w'), const Duration(days: 7), convId),
            _muteOption(ctx, _s(ctx, 'chatlist_mute_forever'), null, convId),
          ],
        ),
      ),
    );
  }

  Widget _muteOption(BuildContext ctx, String label, Duration? duration, String convId) {
    return ListTile(
      title: Text(label, style: ThixPolicy.titleStyle),
      leading: const Icon(Icons.timer_outlined, color: ThixPolicy.primary),
      onTap: () async {
        Navigator.pop(ctx);
        await _guard(() => ref.read(chatListProvider.notifier).toggleMute(convId, duration: duration));
        _showSuccess(_s(context, 'chatlist_muted_success'));
      },
    );
  }

  Future<void> _confirmAndDeleteSingle(ChatConversation conv) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThixPolicy.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rLg)),
        title: Text(_s(ctx, 'chatlist_delete_title'), style: ThixPolicy.titleStyle),
        content: Text(_s(ctx, 'chatlist_delete_message'), style: ThixPolicy.bodyStyle),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(_s(ctx, 'common_cancel'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(_s(ctx, 'common_delete'), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final notifier = ref.read(chatListProvider.notifier);
    await _guard(() async {
      notifier.toggleSelection(conv.id);
      await notifier.bulkDelete();
    });
    _showSuccess(_s(context, 'chatlist_deleted'));
    _refreshAllCounters();
  }

  // ── BULK ACTIONS BAR ──
  Widget _buildBulkActionsBar() {
    final state = ref.watch(chatListProvider);
    final notifier = ref.read(chatListProvider.notifier);

    return Positioned(
      bottom: 16 + MediaQuery.of(context).padding.bottom,
      left: 16,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: ThixPolicy.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: ThixPolicy.border),
            boxShadow: ThixPolicy.shadowSoft(opacity: 0.1),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _s(context, 'chatlist_selected_count', args: ['${state.selectedIds.length}']),
                  style: ThixPolicy.titleStyle.copyWith(fontWeight: ThixPolicy.bold),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.archive_outlined),
                tooltip: _s(context, 'chatlist_archive'),
                onPressed: () async {
                  await _guard(() => notifier.bulkArchive());
                  _showSuccess(_s(context, 'chatlist_bulk_archived'));
                },
              ),
              IconButton(
                icon: const Icon(Icons.done_all_rounded),
                tooltip: _s(context, 'chatlist_mark_read'),
                onPressed: () async {
                  await _guard(() => notifier.bulkMarkAsRead());
                  _showSuccess(_s(context, 'chatlist_bulk_marked_read'));
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: ThixPolicy.danger),
                tooltip: _s(context, 'chatlist_delete'),
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text(_s(ctx, 'chatlist_delete_title')),
                      content: Text(_s(ctx, 'chatlist_bulk_delete_confirm', args: ['${state.selectedIds.length}'])),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(_s(ctx, 'common_cancel'))),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.danger),
                          onPressed: () => Navigator.pop(ctx, true),
                          child: Text(_s(ctx, 'common_delete'), style: const TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    await _guard(() => notifier.bulkDelete());
                    _showSuccess(_s(context, 'chatlist_bulk_deleted'));
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                tooltip: _s(context, 'common_cancel'),
                onPressed: () => notifier.exitSelectionMode(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── SNACKBARS ──
  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(message)),
      ]),
      backgroundColor: ThixPolicy.success,
      behavior: SnackBarBehavior.floating,
    ));
  }

  void _showError(String message) {
    if (!mounted) return;
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.error_outline_rounded, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(message)),
      ]),
      backgroundColor: ThixPolicy.danger,
      behavior: SnackBarBehavior.floating,
    ));
  }

  void _showInfo(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: ThixPolicy.primary,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 1),
    ));
  }

  void _showUndo(String message, VoidCallback onUndo) {
    if (!mounted) return;
    final m = ScaffoldMessenger.of(context);
    m.hideCurrentSnackBar();
    m.showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: ThixPolicy.primary,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 4),
      action: SnackBarAction(
        label: _s(context, 'chatlist_undo'),
        textColor: Colors.white,
        onPressed: onUndo,
      ),
    ));
  }

  void _onSearchChanged(String v) {
    _searchDebounce?.cancel();
    setState(() {}); // met à jour la croix d'effacement
    _searchDebounce = Timer(const Duration(milliseconds: _kSearchDebounceMs), () {
      if (!mounted) return;
      ref.read(chatListProvider.notifier).search(_ListValidators.sanitize(v, maxLength: 100, singleLine: true));
    });
  }

  // ── BUILD ──
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatListProvider);
    final counters = ref.watch(notificationCountersProvider);

    final currentUser = ref.watch(authControllerProvider).value;
    final currentUserName = _ListValidators.sanitize(currentUser?.displayName ?? '', maxLength: _kMaxChatNameLength);
    final currentUserId = currentUser?.id ?? '';
    final currentUserPhoto = _ListValidators.sanitizeUrl(currentUser?.photoUrl);

    final onlineUserIds = ref.watch(presenceProvider);

    final seenUserIds = <String>{};
    final onlineContacts = <ChatConversation>[];
    for (final c in state.filtered) {
      if (c.isGroup || c.isLocked) continue;
      final otherUserId = c.participantIds.firstWhere((id) => id != currentUserId, orElse: () => '');
      if (otherUserId.isNotEmpty && onlineUserIds.onlineUserIds.contains(otherUserId)) {
        if (seenUserIds.add(otherUserId)) onlineContacts.add(c);
      }
    }

    final bellBadge = state.pendingEscalations > 0 ||
        state.totalUnread > 0 ||
        counters.missedCalls > 0 ||
        counters.newConnections > 0;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (state.isSelectionMode) {
          ref.read(chatListProvider.notifier).exitSelectionMode();
        } else if (_selectedNav != 1) {
          setState(() => _selectedNav = 1);
        } else {
          _goToHomepage();
        }
      },
      child: Scaffold(
        backgroundColor: ThixPolicy.surfaceSoft,
        bottomNavigationBar: state.isSelectionMode ? null : _buildFixedBottomNav(state.totalUnread, counters),
        body: Stack(
          children: [
            Positioned(
                top: -100,
                right: -50,
                child: Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: ThixPolicy.primary.withOpacity(0.08)),
                )),
            Positioned(
                bottom: 100,
                left: -100,
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: ThixPolicy.primaryDeep.withOpacity(0.05)),
                )),
            state.isLoading
                ? const Center(child: CircularProgressIndicator(color: ThixPolicy.primary, strokeWidth: 3))
                : RefreshIndicator(
                    color: ThixPolicy.primary,
                    backgroundColor: ThixPolicy.card,
                    onRefresh: () async {
                      HapticFeedback.selectionClick();
                      _refreshAllCounters();
                    },
                    child: RepaintBoundary(
                      child: CustomScrollView(
                        controller: _scroll,
                        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                        slivers: [
                          SliverAppBar(
                            pinned: true,
                            expandedHeight: kToolbarHeight + 20,
                            backgroundColor: Colors.transparent,
                            elevation: 0,
                            scrolledUnderElevation: 2,
                            flexibleSpace: Container(
                              color: ThixPolicy.surfaceSoft,
                              padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s20),
                              alignment: Alignment.bottomCenter,
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 12.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('THIX Chat',
                                        style: ThixPolicy.h1Style.copyWith(fontSize: 24, fontWeight: ThixPolicy.bold, letterSpacing: -0.5)),
                                    Row(children: [
                                      _iconButtonGlass(
                                        icon: Icons.swap_vert_rounded,
                                        semanticsLabel: _s(context, 'chatlist_escalations'),
                                        badge: state.pendingEscalations > 0,
                                        onTap: () {
                                          HapticFeedback.selectionClick();
                                          context.pushNamed('chatEscalationReceived');
                                        },
                                      ),
                                      const SizedBox(width: ThixPolicy.s12),
                                      _iconButtonGlass(
                                        icon: Icons.menu_book_outlined,
                                        semanticsLabel: _s(context, 'chatlist_notebook'),
                                        onTap: _openNotebook,
                                      ),
                                      const SizedBox(width: ThixPolicy.s12),
                                      _iconButtonGlass(
                                        icon: Icons.notifications_none_rounded,
                                        semanticsLabel: _s(context, 'chatlist_notifications'),
                                        badge: bellBadge,
                                        onTap: () => _openNotifications(state.pendingEscalations, counters),
                                      ),
                                    ]),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(ThixPolicy.s20, ThixPolicy.s8, ThixPolicy.s20, ThixPolicy.s12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  StatusStoryRow(
                                    currentUserId: currentUserId,
                                    currentUserAvatar: currentUserPhoto,
                                    currentUserName: currentUserName,
                                  ),
                                  if (onlineContacts.isNotEmpty) ...[
                                    const SizedBox(height: ThixPolicy.s16),
                                    SizedBox(
                                      height: 64,
                                      child: ListView.separated(
                                        scrollDirection: Axis.horizontal,
                                        itemCount: onlineContacts.length,
                                        separatorBuilder: (_, __) => const SizedBox(width: ThixPolicy.s16),
                                        itemBuilder: (c, i) {
                                          final conv = onlineContacts[i];
                                          final safeLabel = _ListValidators.sanitize(conv.displayName.split(' ').first, maxLength: 20);
                                          final safeAvatar = _ListValidators.sanitizeUrl(conv.displayAvatar);
                                          return _onlineAvatarNode(
                                            label: safeLabel.isEmpty ? '?' : safeLabel,
                                            avatarUrl: safeAvatar,
                                            isOnline: true,
                                            onTap: () => _openConversation(conv),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          SliverToBoxAdapter(child: _buildSearchBarGlass()),
                          if (state.pendingEscalations > 0)
                            SliverToBoxAdapter(child: _buildEscalationBanner(state.pendingEscalations)),
                          SliverToBoxAdapter(child: _buildFilters(state.filterIndex)),
                          const SliverToBoxAdapter(child: SizedBox(height: ThixPolicy.s16)),
                          SliverPadding(
                            padding: const EdgeInsets.only(top: 8),
                            sliver: _chatListSliver(state, currentUserId, currentUserName, onlineUserIds.onlineUserIds),
                          ),
                          if (state.isLoadingMore)
                            const SliverToBoxAdapter(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 28),
                                child: Center(child: CircularProgressIndicator(color: ThixPolicy.primary, strokeWidth: 3)),
                              ),
                            ),
                          const SliverToBoxAdapter(child: SizedBox(height: 110)),
                        ],
                      ),
                    ),
                  ),
            if (state.isSelectionMode) _buildBulkActionsBar(),
          ],
        ),
      ),
    );
  }

  Widget _iconButtonGlass({
    required IconData icon,
    required String semanticsLabel,
    required VoidCallback onTap,
    bool badge = false,
  }) {
    return Semantics(
      button: true,
      label: semanticsLabel,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: ThixPolicy.card,
            shape: BoxShape.circle,
            border: Border.all(color: ThixPolicy.border),
            boxShadow: ThixPolicy.shadowSoft(opacity: 0.04),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(icon, size: 20, color: ThixPolicy.textMain),
              if (badge)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: ThixPolicy.danger,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _onlineAvatarNode({
    required String label,
    required String? avatarUrl,
    required bool isOnline,
    VoidCallback? onTap,
  }) {
    return Semantics(
      button: true,
      label: '$label${isOnline ? " (${_s(context, 'chatlist_online')})" : ""}',
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap?.call();
        },
        child: SizedBox(
          width: 52,
          child: Column(
            children: [
              Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: ThixPolicy.card, width: 2),
                      boxShadow: ThixPolicy.shadowSoft(opacity: 0.05),
                    ),
                    child: CircleAvatar(
                      radius: 20,
                      backgroundColor: ThixPolicy.surface,
                      backgroundImage: avatarUrl != null ? CachedNetworkImageProvider(avatarUrl) : null,
                      child: avatarUrl == null ? const Icon(Icons.person, color: ThixPolicy.primaryDeep, size: 20) : null,
                    ),
                  ),
                  if (isOnline)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: ThixPolicy.success,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                label.isEmpty ? '?' : label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ThixPolicy.captionStyle.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.textMain),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBarGlass() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(ThixPolicy.s20, 0, ThixPolicy.s20, ThixPolicy.s16),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: ThixPolicy.card,
          borderRadius: BorderRadius.circular(ThixPolicy.inputRadius),
          border: Border.all(color: ThixPolicy.border),
        ),
        child: Semantics(
          label: _s(context, 'chatlist_search_label'),
          textField: true,
          child: TextField(
            controller: _searchCtrl,
            onChanged: _onSearchChanged,
            textInputAction: TextInputAction.search,
            style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textMain, fontWeight: ThixPolicy.medium),
            decoration: InputDecoration(
              hintText: _s(context, 'chatlist_search_hint'),
              hintStyle: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textSecondary),
              prefixIcon: const Icon(Icons.search_rounded, size: 20, color: ThixPolicy.textSecondary),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? Semantics(
                      button: true,
                      label: _s(context, 'common_clear'),
                      child: IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18, color: ThixPolicy.textSecondary),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          _searchDebounce?.cancel();
                          _searchCtrl.clear();
                          setState(() {});
                          ref.read(chatListProvider.notifier).search('');
                        },
                      ),
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEscalationBanner(int pending) {
    return Semantics(
      button: true,
      label: _s(context, 'chatlist_pending_escalations'),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          context.pushNamed('chatEscalationReceived');
        },
        child: Container(
          margin: const EdgeInsets.fromLTRB(ThixPolicy.s20, 0, ThixPolicy.s20, ThixPolicy.s16),
          padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16, vertical: ThixPolicy.s12),
          decoration: BoxDecoration(
            color: ThixPolicy.danger.withOpacity(0.08),
            borderRadius: BorderRadius.circular(ThixPolicy.rMd),
            border: Border.all(color: ThixPolicy.danger.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              const _PulseDot(color: ThixPolicy.danger, size: 10),
              const SizedBox(width: ThixPolicy.s12),
              Expanded(
                child: Text('$pending ${_s(context, 'chatlist_pending_escalations')}',
                    style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.danger, fontWeight: ThixPolicy.bold)),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, color: ThixPolicy.danger, size: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilters(int selected) {
    final filterLabels = [
      _s(context, 'chatlist_filter_all'),
      _s(context, 'chatlist_filter_unread'),
      _s(context, 'chatlist_filter_teams'),
      _s(context, 'chatlist_filter_personal'),
      _s(context, 'chatlist_filter_pinned'),
      _s(context, 'chatlist_filter_archived'),
    ];

    return SizedBox(
      height: 34,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s20),
        scrollDirection: Axis.horizontal,
        itemCount: _filterKeys.length,
        itemBuilder: (ctx, i) {
          final sel = selected == i;
          return Padding(
            padding: const EdgeInsets.only(right: ThixPolicy.s8),
            child: Semantics(
              button: true,
              selected: sel,
              label: filterLabels[i],
              child: InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  ref.read(chatListProvider.notifier).setFilter(i);
                },
                borderRadius: BorderRadius.circular(20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: sel ? ThixPolicy.primary : ThixPolicy.card,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: sel ? ThixPolicy.primary : ThixPolicy.border, width: 1.2),
                  ),
                  child: Text(
                    filterLabels[i],
                    style: ThixPolicy.bodySmallStyle.copyWith(
                      fontWeight: sel ? ThixPolicy.bold : ThixPolicy.semiBold,
                      color: sel ? Colors.white : ThixPolicy.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _chatListSliver(
    dynamic state,
    String currentUserId,
    String currentUserName,
    Set<String> onlineUserIds,
  ) {
    final List<ChatConversation> list = state.filtered;

    if (list.isEmpty) {
      final searching = _searchCtrl.text.trim().isNotEmpty;
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 80),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: ThixPolicy.surfaceSoft,
                  shape: BoxShape.circle,
                  border: Border.all(color: ThixPolicy.border),
                ),
                child: Icon(searching ? Icons.search_off_rounded : Icons.chat_bubble_outline_rounded,
                    size: 40, color: ThixPolicy.primaryDeep),
              ),
              const SizedBox(height: ThixPolicy.s16),
              Text(
                searching
                    ? _s(context, 'chatlist_no_results')
                    : (state.filterIndex == ChatFilter.archived
                        ? _s(context, 'chatlist_no_archived')
                        : _s(context, 'chatlist_no_conversation')),
                style: ThixPolicy.titleStyle.copyWith(color: ThixPolicy.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (ctx, idx) {
          final conv = list[idx];
          final last = conv.lastMessage;
          final t = last?.createdAt ?? conv.updatedAt;
          final unread = conv.unreadCount > 0;
          final isSelected = state.selectedIds.contains(conv.id) as bool;
          final escPending = _isEscalationPending(conv);

          final otherUserId = conv.participantIds.firstWhere((id) => id != currentUserId, orElse: () => '');
          final isOnline = onlineUserIds.contains(otherUserId);

          String chatName = _ListValidators.sanitize(conv.displayName, maxLength: _kMaxChatNameLength);
          final chatAvatar = _ListValidators.sanitizeUrl(conv.displayAvatar);

          if (conv.isGroup) {
            if (chatName.isEmpty) chatName = _s(context, 'chatlist_group_thix');
          } else if (chatName.trim() == currentUserName.trim() || chatName.isEmpty) {
            final shortId = otherUserId.length > 4 ? otherUserId.substring(0, 4) : otherUserId;
            chatName = '${_s(context, 'chatlist_contact_thix')} (ID: $shortId)';
          }

          final tile = _ConversationTile(
            conv: conv,
            chatName: chatName,
            chatAvatar: chatAvatar,
            isOnline: isOnline,
            unread: unread,
            isSelected: isSelected,
            escalationPending: escPending,
            currentUserId: currentUserId,
            otherUserId: otherUserId,
            lastMessage: last,
            timeText: _fmt(t),
            preview: _buildPreview(conv, currentUserId),
            onTap: () {
              if (state.isSelectionMode as bool) {
                ref.read(chatListProvider.notifier).toggleSelection(conv.id);
              } else {
                _openConversation(conv);
              }
            },
            onLongPress: () {
              final n = ref.read(chatListProvider.notifier);
              if (!(state.isSelectionMode as bool)) n.enterSelectionMode();
              n.toggleSelection(conv.id);
            },
            onContextMenu: () => _showContextMenu(conv),
          );

          // Swipe : droite = lu / non lu · gauche = archiver (avec ANNULER)
          return Dismissible(
            key: ValueKey('tile_${conv.id}'),
            direction: (state.isSelectionMode as bool) ? DismissDirection.none : DismissDirection.horizontal,
            confirmDismiss: (dir) async {
              HapticFeedback.selectionClick();
              final notifier = ref.read(chatListProvider.notifier);
              if (dir == DismissDirection.endToStart) {
                final wasArchived = conv.isArchived;
                await _guard(() => notifier.toggleArchive(conv.id));
                _showUndo(
                  wasArchived ? _s(context, 'chatlist_unarchived') : _s(context, 'chatlist_archived'),
                  () => _guard(() => notifier.toggleArchive(conv.id)),
                );
              } else if (unread) {
                await _guard(() => notifier.markAsRead(conv.id));
                _showInfo(_s(context, 'chatlist_marked_read'));
              } else {
                await _guard(() => notifier.markAsUnread(conv.id));
                _showInfo(_s(context, 'chatlist_marked_unread'));
              }
              return false;
            },
            background: Container(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.only(left: 24),
              color: ThixPolicy.primary.withOpacity(0.12),
              child: const Icon(Icons.done_all_rounded, color: ThixPolicy.primary),
            ),
            secondaryBackground: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 24),
              color: ThixPolicy.warning.withOpacity(0.12),
              child: const Icon(Icons.archive_outlined, color: ThixPolicy.warning),
            ),
            child: tile,
          );
        },
        childCount: list.length,
      ),
    );
  }

  // ==========================================================================
  // 🧭 NAVBAR FIXE + ONDULATION + CRAYON
  // ==========================================================================
  Widget _buildFixedBottomNav(int unread, NotificationCounters counters) {
    return CustomPaint(
      painter: _WaveNavPainter(color: ThixPolicy.card),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 66,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _navItem(Icons.people_alt_outlined, Icons.people_alt, _s(context, 'chatlist_network'), 0, counters.newConnections),
              _navItem(Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded, _s(context, 'chatlist_discussions'), 1, unread),
              Semantics(
                button: true,
                label: _s(context, 'chatlist_create_new'),
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    _showCreateMenu();
                  },
                  child: Transform.translate(
                    offset: const Offset(0, -10),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: ThixPolicy.primary.withOpacity(0.12),
                        shape: BoxShape.circle,
                        border: Border.all(color: ThixPolicy.primary.withOpacity(0.35), width: 1.5),
                      ),
                      child: Icon(Icons.edit_rounded, color: ThixPolicy.primary.withOpacity(0.9), size: 20),
                    ),
                  ),
                ),
              ),
              _navItem(Icons.call_outlined, Icons.call, _s(context, 'chatlist_calls'), 2, counters.missedCalls),
              _navItem(Icons.settings_outlined, Icons.settings, _s(context, 'chatlist_settings'), 3, 0),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(IconData iconOutlined, IconData iconFilled, String label, int idx, int badge) {
    final isSelected = _selectedNav == idx;
    return Semantics(
      button: true,
      label: badge > 0 ? '$label ($badge)' : label,
      selected: isSelected,
      child: InkWell(
        onTap: () => _navigateTo(idx),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                isSelected ? iconFilled : iconOutlined,
                color: isSelected ? ThixPolicy.primary.withOpacity(0.9) : ThixPolicy.textSecondary.withOpacity(0.65),
                size: 24,
              ),
              if (badge > 0)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: ThixPolicy.danger,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Text(
                      badge > 99 ? '99+' : '$badge',
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _fmt(DateTime d) {
    final localDate = d.toLocal();
    final now = DateTime.now();
    final day = DateTime(localDate.year, localDate.month, localDate.day);
    final today = DateTime(now.year, now.month, now.day);

    if (day == today) return DateFormat('HH:mm').format(localDate);
    if (day == today.subtract(const Duration(days: 1))) return _s(context, 'chatlist_yesterday');
    if (now.difference(localDate).inDays < 7) {
      try {
        return DateFormat('EEEE', Localizations.localeOf(context).languageCode).format(localDate);
      } catch (_) {
        return DateFormat('EEEE', 'fr_FR').format(localDate);
      }
    }
    return DateFormat('dd/MM/yy').format(localDate);
  }
}

// ============================================================================
// ONDULATION NAVBAR
// ============================================================================
class _WaveNavPainter extends CustomPainter {
  final Color color;
  const _WaveNavPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(0, 22)
      ..lineTo(cx - 56, 22)
      ..quadraticBezierTo(cx - 26, 22, cx - 18, 10)
      ..quadraticBezierTo(cx, -8, cx + 18, 10)
      ..quadraticBezierTo(cx + 26, 22, cx + 56, 22)
      ..lineTo(size.width, 22)
      ..lineTo(size.width, size.height)
      ..close();

    canvas.drawPath(path, Paint()..color = color..style = PaintingStyle.fill);
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.black.withOpacity(0.05)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ============================================================================
// PULSE (pastille + barres)
// ============================================================================
class _PulseDot extends StatefulWidget {
  final Color color;
  final double size;
  const _PulseDot({required this.color, this.size = 10});

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

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
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
        ),
      ),
    );
  }
}

class _PulseWrap extends StatefulWidget {
  final Widget child;
  final bool active;
  const _PulseWrap({required this.child, required this.active});

  @override
  State<_PulseWrap> createState() => _PulseWrapState();
}

class _PulseWrapState extends State<_PulseWrap> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void initState() {
    super.initState();
    if (widget.active) _c.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _PulseWrap old) {
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
// CONVERSATION TILE
// ============================================================================
class _ConversationTile extends StatelessWidget {
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
  final _Preview preview;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onContextMenu;

  const _ConversationTile({
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
    final clientName = _ListValidators.sanitize(conv.clientName ?? chatName, maxLength: 40);
    final agentName = _ListValidators.sanitize(conv.escalatedByName ?? _s(context, 'chatlist_agent'), maxLength: 40);
    final clientAvatar = _ListValidators.sanitizeUrl(conv.clientAvatar ?? chatAvatar);
    final agentAvatar = _ListValidators.sanitizeUrl(conv.agentAvatar);

    // Fond : sélection > non lu (léger surlignage) > transparent
    final bg = isSelected
        ? ThixPolicy.primary.withOpacity(0.10)
        : (unread ? ThixPolicy.primary.withOpacity(0.05) : Colors.transparent);

    final baseStyle = ThixPolicy.bodySmallStyle.copyWith(
      fontWeight: unread || preview.strong ? ThixPolicy.semiBold : ThixPolicy.regular,
      color: preview.color ?? (unread ? ThixPolicy.textMain : ThixPolicy.textSecondary),
    );

    return Semantics(
      button: true,
      label: '$chatName. ${unread ? "${conv.unreadCount} ${_s(context, 'chatlist_unread_label')}. " : ""}${preview.text}',
      child: Material(
        color: bg,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Stack(
            children: [
              // ── BARRES GAUCHES : escalade = 2 barres (agent rouge + client bleu), épinglé = or ──
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: isEsc
                    ? _PulseWrap(
                        active: escalationPending,
                        child: Row(
                          children: [
                            Container(width: 4, color: ThixPolicy.danger),
                            const SizedBox(width: 2),
                            Container(width: 4, color: ThixPolicy.primary),
                          ],
                        ),
                      )
                    : Container(width: 3, color: conv.isPinned ? ThixPolicy.gold : Colors.transparent),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s20, vertical: 12),
                child: Row(
                  children: [
                    Stack(
                      children: [
                        if (isEsc)
                          _EscalationAvatars(
                            clientName: clientName,
                            clientAvatar: clientAvatar,
                            agentName: agentName,
                            agentAvatar: agentAvatar,
                            pending: escalationPending,
                          )
                        else
                          Stack(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: ThixPolicy.card, width: 1.5),
                                  boxShadow: ThixPolicy.shadowSoft(opacity: 0.03),
                                ),
                                child: CircleAvatar(
                                  radius: 26,
                                  backgroundColor: ThixPolicy.surface,
                                  backgroundImage: chatAvatar != null ? CachedNetworkImageProvider(chatAvatar!) : null,
                                  child: chatAvatar == null
                                      ? Text(_ListValidators.safeInitial(chatName),
                                          style: ThixPolicy.h3Style.copyWith(color: ThixPolicy.textSecondary))
                                      : null,
                                ),
                              ),
                              if (!conv.isGroup && isOnline)
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    width: 14,
                                    height: 14,
                                    decoration: BoxDecoration(
                                      color: ThixPolicy.success,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2.5),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        if (isSelected)
                          Positioned(
                            top: 0,
                            right: 0,
                            child: Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: ThixPolicy.primary,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: const Icon(Icons.check, size: 14, color: Colors.white),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: ThixPolicy.s16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Consumer(
                                  builder: (context, ref, _) {
                                    CertificationTier? tier;
                                    CertificationStatus? status;
                                    bool isCertified = false;
                                    bool isLegacyVerified = false;

                                    if (!conv.isGroup && !isEsc && otherUserId.isNotEmpty) {
                                      final profileData = ref.watch(userProfileProvider(otherUserId)).valueOrNull;
                                      if (profileData != null) {
                                        tier = CertificationTierX.parse(profileData['certification_tier']);
                                        status = CertificationStatusX.parse(profileData['certification_status']);
                                        isCertified = status == CertificationStatus.approved || status == CertificationStatus.generated;
                                        isLegacyVerified = profileData['is_verified'] == true;
                                      }
                                    }

                                    return Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            chatName.isEmpty ? _s(context, 'chatlist_unknown') : chatName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: ThixPolicy.titleStyle.copyWith(
                                              fontSize: 15,
                                              fontWeight: unread ? ThixPolicy.bold : ThixPolicy.semiBold,
                                              color: ThixPolicy.textMain,
                                            ),
                                          ),
                                        ),
                                        if (isCertified)
                                          CertificationNameBadge(
                                            tier: tier,
                                            status: status,
                                            showLabel: false,
                                            iconSize: 15,
                                            padding: const EdgeInsets.only(left: 4),
                                          )
                                        else if (isLegacyVerified)
                                          const Padding(
                                            padding: EdgeInsets.only(left: 4),
                                            child: Icon(Icons.verified_rounded, color: ThixPolicy.gold, size: 15),
                                          ),
                                        if (isEsc) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: ThixPolicy.danger.withOpacity(0.12),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: ThixPolicy.danger.withOpacity(0.4)),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.swap_vert_rounded, size: 11, color: ThixPolicy.danger),
                                                const SizedBox(width: 3),
                                                Text(_s(context, 'chatlist_escalated'),
                                                    style: ThixPolicy.microStyle.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.danger)),
                                              ],
                                            ),
                                          ),
                                        ] else if (conv.isGroup) ...[
                                          const SizedBox(width: 4),
                                          const Icon(Icons.groups_rounded, size: 14, color: ThixPolicy.textSecondary),
                                        ],
                                        if (conv.isPinned) ...[
                                          const SizedBox(width: 4),
                                          const Icon(Icons.push_pin_rounded, size: 14, color: ThixPolicy.gold),
                                        ],
                                        if (muted) ...[
                                          const SizedBox(width: 4),
                                          const Icon(Icons.volume_off_rounded, size: 14, color: ThixPolicy.warning),
                                        ],
                                        if (conv.isLocked) ...[
                                          const SizedBox(width: 4),
                                          const Icon(Icons.lock_rounded, size: 14, color: ThixPolicy.danger),
                                        ],
                                      ],
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                timeText,
                                style: ThixPolicy.captionStyle.copyWith(
                                  fontWeight: unread ? ThixPolicy.bold : ThixPolicy.medium,
                                  color: unread && !muted ? ThixPolicy.primary : ThixPolicy.textSecondary,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.more_vert_rounded, size: 18, color: ThixPolicy.textSecondary),
                                onPressed: onContextMenu,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              ),
                            ],
                          ),
                          // ── ESCALADE : les DEUX profils nommés, couleurs = barres ──
                          if (isEsc) ...[
                            const SizedBox(height: 2),
                            Text.rich(
                              TextSpan(children: [
                                TextSpan(
                                  text: '${_s(context, 'chatlist_client_label')}: $clientName',
                                  style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.primary, fontWeight: ThixPolicy.semiBold),
                                ),
                                TextSpan(text: '  •  ', style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textMuted)),
                                TextSpan(
                                  text: '${_s(context, 'chatlist_agent_label')}: $agentName',
                                  style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.danger, fontWeight: ThixPolicy.semiBold),
                                ),
                              ]),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              ListMessageStatusLights.fromMessage(lastMessage, currentUserId),
                              if (preview.icon != null)
                                Padding(
                                  padding: const EdgeInsets.only(right: 4),
                                  child: Icon(preview.icon,
                                      size: 14,
                                      color: preview.color ?? (unread ? ThixPolicy.textMain : ThixPolicy.textSecondary)),
                                ),
                              Expanded(
                                child: Text.rich(
                                  TextSpan(
                                    style: baseStyle,
                                    children: [
                                      if (preview.prefix != null)
                                        TextSpan(
                                          text: '${preview.prefix} ',
                                          style: baseStyle.copyWith(color: ThixPolicy.danger, fontWeight: ThixPolicy.bold),
                                        ),
                                      TextSpan(text: preview.text.isEmpty ? '—' : preview.text),
                                    ],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (unread)
                                Container(
                                  margin: const EdgeInsets.only(left: 10),
                                  constraints: const BoxConstraints(minWidth: 22),
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: muted ? ThixPolicy.textMuted : ThixPolicy.primary,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: muted
                                        ? null
                                        : [
                                            BoxShadow(
                                              color: ThixPolicy.primary.withOpacity(0.3),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    conv.unreadCount > 99 ? '99+' : '${conv.unreadCount}',
                                    style: ThixPolicy.microStyle.copyWith(color: Colors.white, fontWeight: ThixPolicy.bold),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// FEUX DE STATUT (même logique que MessageStatusTicks de la bulle)
// vert = lu · orange = distribué · gris = envoyé
// ============================================================================
class ListMessageStatusLights extends StatelessWidget {
  final bool isDelivered;
  final bool isRead;
  final bool show;

  const ListMessageStatusLights({
    super.key,
    this.isDelivered = false,
    this.isRead = false,
    this.show = true,
  });

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
      decoration: BoxDecoration(
        color: ThixPolicy.inkDeep.withOpacity(0.8),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _dot(ThixPolicy.success, isRead),
          _dot(ThixPolicy.warning, !isRead && isDelivered),
          _dot(ThixPolicy.textMuted, !isRead && !isDelivered),
        ],
      ),
    );
  }

  Widget _dot(Color base, bool active) {
    return Container(
      width: 5,
      height: 5,
      decoration: BoxDecoration(shape: BoxShape.circle, color: active ? base : base.withOpacity(0.22)),
    );
  }
}

// ============================================================================
// ESCALATION AVATARS : client (anneau bleu) + agent (anneau rouge)
// ============================================================================
class _EscalationAvatars extends StatelessWidget {
  final String clientName;
  final String? clientAvatar;
  final String agentName;
  final String? agentAvatar;
  final bool pending;

  const _EscalationAvatars({
    required this.clientName,
    this.clientAvatar,
    required this.agentName,
    this.agentAvatar,
    this.pending = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 62,
      height: 46,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(left: 0, top: 4, child: _miniAvatar(clientAvatar, clientName, ThixPolicy.primary)),
          Positioned(left: 24, top: 4, child: _miniAvatar(agentAvatar, agentName, ThixPolicy.danger)),
          Positioned(
            right: 0,
            bottom: 0,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (pending) const _PulseDot(color: ThixPolicy.danger, size: 16),
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: ThixPolicy.danger,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: const Icon(Icons.swap_vert_rounded, size: 10, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniAvatar(String? url, String name, Color ring) {
    final safeName = _ListValidators.sanitize(name, maxLength: 30);
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: ring, width: 2),
        boxShadow: ThixPolicy.shadowSoft(opacity: 0.05),
      ),
      child: CircleAvatar(
        radius: 17,
        backgroundColor: ring.withOpacity(0.15),
        backgroundImage: url != null ? CachedNetworkImageProvider(url) : null,
        child: url == null ? Text(_ListValidators.safeInitial(safeName), style: ThixPolicy.labelStyle.copyWith(color: ring)) : null,
      ),
    );
  }
}
