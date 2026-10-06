// lib/presentation/chat/widgets/chat_message_bubble.dart
import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:intl/intl.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/models/chat/chat_message.dart';
import 'package:thix_id/presentation/chat/encryption_service.dart';
import 'package:thix_id/presentation/chat/widgets/audio_player.dart';
import 'package:thix_id/presentation/chat/widgets/chat_code_snippet.dart';
import 'package:thix_id/presentation/chat/widgets/image_viewer.dart';
import 'package:thix_id/presentation/chat/widgets/sentiment_indicator.dart';
import 'package:thix_id/services/chat/media_saver.dart';

// ============================================================================
// CONSTANTS
// ============================================================================
const Duration _kDownloadTimeout = Duration(seconds: 60);
const Duration _kRetryDelay = Duration(milliseconds: 400);
const int _kMaxRetries = 1;
const int _kMaxContentLength = 5000;
const int _kMaxNameLength = 80;
const int _kMaxFileNameLength = 100;
const int _kMaxReactionLength = 10;
const double _kBubbleMaxWidthRatio = 0.85;
const int _kEditWindowMinutes = 15;

/// Clé l10n conservée ; si elle manque dans les fichiers ARB, on affiche le
/// texte anglais de secours au lieu de la clé brute.
String _t(AppLocalizations l10n, String key, String fallback) {
  final s = l10n.t(key);
  return (s.isEmpty || s == key) ? fallback : s;
}

// ============================================================================
// VALIDATORS
// ============================================================================
class _BubbleValidators {
  _BubbleValidators._();

  static final RegExp _ctrlKeepNl = RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]');
  static final RegExp _ctrlAll = RegExp(r'[\x00-\x1F\x7F]');
  static final RegExp _bidi = RegExp(r'[\u200B\u200E\u200F\u202A-\u202E\u2066-\u2069\uFEFF]');
  static final RegExp _tags = RegExp(r'<[a-zA-Z/!?][^>]*>');
  static final RegExp _jsScheme = RegExp(r'(javascript|vbscript)\s*:', caseSensitive: false);

  static String sanitize(String? input, {int maxLength = 500}) {
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
        .replaceAll(_bidi, '')
        .trim();
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

  static String friendlyError(dynamic e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('timeout')) return 'Délai dépassé. Vérifiez votre connexion.';
    if (msg.contains('network') || msg.contains('socket')) return 'Erreur réseau. Réessayez.';
    if (msg.contains('permission') || msg.contains('policy')) return 'Accès non autorisé.';
    if (msg.contains('not found')) return 'Ressource introuvable.';
    if (msg.contains('no space') || msg.contains('storage')) return 'Espace insuffisant.';
    return 'Une erreur est survenue. Réessayez.';
  }

  static bool looksEncrypted(String raw) {
    if (raw.startsWith('ENCv1:') || raw.startsWith('🔒')) return true;
    if (raw.length > 20 &&
        !raw.contains(' ') &&
        RegExp(r'^[A-Za-z0-9+/=]+$').hasMatch(raw.replaceFirst(RegExp(r'^ENCv1:'), ''))) {
      return true;
    }
    return false;
  }
}

// ============================================================================
// HELPERS
// ============================================================================
Future<T> _bubbleRetry<T>(
  Future<T> Function() fn, {
  required String label,
  int maxRetries = _kMaxRetries,
  Duration timeout = _kDownloadTimeout,
}) async {
  int attempt = 0;
  while (true) {
    try {
      return await fn().timeout(timeout);
    } on TimeoutException {
      attempt++;
      if (attempt > maxRetries) {
        debugPrint('[Bubble] ❌ $label: timeout after $attempt attempts');
        throw TimeoutException('$label: délai dépassé');
      }
      await Future.delayed(_kRetryDelay);
    } catch (e) {
      debugPrint('[Bubble] ❌ $label error: $e');
      rethrow;
    }
  }
}

// ============================================================================
// CHAT MESSAGE BUBBLE
// Le swipe (droite = répondre, gauche = menu) est géré par chat_screen.dart
// pour TOUS les messages : aucun Dismissible ici (sinon double déclenchement).
// ============================================================================
class ChatMessageBubble extends ConsumerStatefulWidget {
  final ChatMessage message;
  final bool isOwn;
  final VoidCallback? onReply;
  final void Function(String reaction)? onReaction;
  final VoidCallback? onDelete;
  final VoidCallback? onDeleteForAll; // conservé pour compatibilité
  final void Function(String newContent)? onEdit;
  final VoidCallback? onForward;
  final VoidCallback? onPin;
  final VoidCallback? onStar;
  final VoidCallback? onViewOnceOpened;
  final ChatMessage? replyToMessage;
  final bool isEphemeralActive;
  final bool isInternalNote;
  final bool isAgentView;
  final bool isFirstInGroup;
  final bool isLastInGroup;

  const ChatMessageBubble({
    super.key,
    required this.message,
    required this.isOwn,
    this.onReply,
    this.onReaction,
    this.onDelete,
    this.onDeleteForAll,
    this.onEdit,
    this.onForward,
    this.onPin,
    this.onStar,
    this.onViewOnceOpened,
    this.replyToMessage,
    this.isEphemeralActive = false,
    this.isInternalNote = false,
    this.isAgentView = false,
    this.isFirstInGroup = true,
    this.isLastInGroup = true,
  });

  @override
  ConsumerState<ChatMessageBubble> createState() => _ChatMessageBubbleState();
}

class _ChatMessageBubbleState extends ConsumerState<ChatMessageBubble> {
  bool _showReact = false;
  bool _isDecrypted = false;
  bool _isUnlocking = false;
  String? _decrypted;

  static const _quickReactions = ['❤️', '😂', '🔥', '👍', '😮', '😢'];

  static final _imageExtRegex = RegExp(
    r'\.(jpg|jpeg|png|gif|webp|heic|heif|svg)(\?|$)',
    caseSensitive: false,
  );

  ChatMessage get m => widget.message;
  bool get _isNote => widget.isInternalNote || m.isInternalNote;

  bool get _shouldHideNote => _isNote && !widget.isAgentView;

  bool get _canEdit {
    if (!widget.isOwn) return false;
    if (m.isDeleted || m.isDeletedForAll) return false;
    if (m.hasMedia) return false;
    if (m.isEphemeral) return false;
    final elapsed = DateTime.now().toUtc().difference(m.createdAt.toUtc());
    return elapsed.inMinutes < _kEditWindowMinutes;
  }

  Color get _bubbleColor {
    if (_isNote) return ThixPolicy.warning.withOpacity(0.15);
    return widget.isOwn ? ThixPolicy.primary : ThixPolicy.card;
  }

  Color get _textColor => (widget.isOwn && !_isNote) ? Colors.white : ThixPolicy.textMain;
  Color get _timeColor => (widget.isOwn && !_isNote) ? Colors.white70 : ThixPolicy.textMuted;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (_shouldHideNote) return const SizedBox.shrink();

    // 💣 Auto-destruction : expiré → rien du tout (aucune trace, aucun popup).
    if (m.isExpired || (m.isEphemeral && m.isDeleted)) return const SizedBox.shrink();

    if (m.isDeleted || m.isDeletedForAll) {
      return _DeletedBubble(isOwn: widget.isOwn, isDeletedForAll: m.isDeletedForAll);
    }

    if (m.isViewOnce && m.hasBeenViewed) return const SizedBox.shrink();

    final topSpacing = widget.isFirstInGroup ? 6.0 : 1.5;
    final bottomSpacing = widget.isLastInGroup ? 6.0 : 1.5;
    final tailRadius = widget.isLastInGroup ? 4.0 : 16.0;

    final bubbleContent = _buildBubbleContent(l10n, tailRadius);

    return Padding(
      padding: EdgeInsets.only(top: topSpacing, bottom: bottomSpacing),
      child: Column(
        crossAxisAlignment: widget.isOwn ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (m.isForwarded)
            Padding(
              padding: EdgeInsets.only(
                left: widget.isOwn ? 0 : 12,
                right: widget.isOwn ? 12 : 0,
                bottom: 2,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: widget.isOwn ? MainAxisAlignment.end : MainAxisAlignment.start,
                children: [
                  const Icon(Icons.forward_rounded, size: 12, color: ThixPolicy.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    _t(l10n, 'bubble_forwarded', 'Forwarded'),
                    style: ThixPolicy.microStyle.copyWith(color: ThixPolicy.textMuted),
                  ),
                ],
              ),
            ),
          if (!widget.isOwn && widget.isFirstInGroup && m.senderName.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 2),
              child: Text(
                _BubbleValidators.sanitize(m.senderName, maxLength: _kMaxNameLength),
                style: ThixPolicy.captionStyle.copyWith(
                  fontSize: 11,
                  fontWeight: ThixPolicy.bold,
                  color: ThixPolicy.primary,
                ),
              ),
            ),
          if (_isNote && widget.isAgentView)
            Padding(
              padding: const EdgeInsets.only(bottom: 4, left: 4, right: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline, size: 12, color: ThixPolicy.warning),
                  const SizedBox(width: 4),
                  Text(
                    _t(l10n, 'bubble_internal_note', 'Internal note'),
                    style: ThixPolicy.microStyle.copyWith(
                      fontSize: 10,
                      fontWeight: ThixPolicy.bold,
                      color: ThixPolicy.warning,
                    ),
                  ),
                ],
              ),
            ),
          GestureDetector(
            onLongPress: _openActions,
            onDoubleTap: () {
              HapticFeedback.lightImpact();
              widget.onReaction?.call('❤️');
            },
            child: Align(
              alignment: widget.isOwn ? Alignment.centerRight : Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * _kBubbleMaxWidthRatio,
                ),
                child: bubbleContent,
              ),
            ),
          ),
          if (_showReact)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: _QuickReactions(
                onPick: (r) {
                  HapticFeedback.selectionClick();
                  setState(() => _showReact = false);
                  widget.onReaction?.call(r);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBubbleContent(AppLocalizations l10n, double tailRadius) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          margin: EdgeInsets.only(
            left: widget.isOwn ? 40 : 4,
            right: widget.isOwn ? 4 : 40,
          ),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          decoration: BoxDecoration(
            color: _bubbleColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(widget.isOwn ? 16 : tailRadius),
              bottomRight: Radius.circular(widget.isOwn ? tailRadius : 16),
            ),
            border: _isNote
                ? Border.all(color: ThixPolicy.warning.withOpacity(0.35))
                : Border.all(color: ThixPolicy.border.withOpacity(0.6)),
            boxShadow: ThixPolicy.shadowSoft(opacity: 0.04),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.replyToMessage != null)
                _ReplyQuote(message: widget.replyToMessage!, isOwn: widget.isOwn),
              _buildBody(l10n),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (m.isEdited) ...[
                    Text(
                      _t(l10n, 'bubble_edited', 'edited'),
                      style: TextStyle(fontSize: 9, color: _timeColor, fontStyle: FontStyle.italic),
                    ),
                    const SizedBox(width: 4),
                  ],

                  // ⏱️ Minuteur d'auto-destruction EN ROUGE
                  if (m.isEphemeral || widget.isEphemeralActive) ...[
                    _EphemeralTimerWidget(
                      message: m,
                      onTick: () {
                        // À l'expiration : simple rebuild. Le retrait de la liste est fait
                        // par chat_screen (purge à la seconde). Aucun appel serveur, aucun popup.
                        if (mounted) setState(() {});
                      },
                    ),
                    const SizedBox(width: 6),
                  ],

                  if (m.sentiment != null && widget.isAgentView) ...[
                    SentimentIndicator(result: m.sentiment!),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    DateFormat('HH:mm').format(m.createdAt.toLocal()),
                    style: TextStyle(fontSize: 10, color: _timeColor),
                  ),
                  if (widget.isOwn) ...[
                    const SizedBox(width: 4),
                    MessageStatusTicks(isDelivered: m.isDelivered, isRead: m.isRead),
                  ],
                ],
              ),
            ],
          ),
        ),
        if (m.isPinned)
          Positioned(
            top: -8,
            right: widget.isOwn ? 48 : null,
            left: widget.isOwn ? null : 48,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: ThixPolicy.gold,
                shape: BoxShape.circle,
                border: Border.all(color: ThixPolicy.card, width: 1.5),
              ),
              child: const Icon(Icons.push_pin_rounded, size: 10, color: Colors.white),
            ),
          ),
        if (m.isStarred)
          Positioned(
            top: -8,
            right: widget.isOwn ? 68 : null,
            left: widget.isOwn ? null : 68,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: ThixPolicy.primary,
                shape: BoxShape.circle,
                border: Border.all(color: ThixPolicy.card, width: 1.5),
              ),
              child: const Icon(Icons.star_rounded, size: 10, color: Colors.white),
            ),
          ),
        if (m.reactions.isNotEmpty)
          Positioned(
            bottom: -10,
            right: widget.isOwn ? 16 : null,
            left: widget.isOwn ? null : 16,
            child: _ReactionsChip(reactions: m.reactions),
          ),
      ],
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    if (m.isCodeSnippet && (m.codeContent?.isNotEmpty ?? false)) {
      return ChatCodeSnippet(code: m.codeContent!, language: m.codeLanguage ?? 'text');
    }

    if (m.mediaType == 'audio' && m.mediaUrl != null) {
      final safeUrl = _BubbleValidators.sanitizeUrl(m.mediaUrl);
      if (safeUrl != null) return AudioPlayerWidget(audioUrl: safeUrl);
    }

    final isImage = m.mediaType == 'image' ||
        (m.mediaUrl != null && _imageExtRegex.hasMatch(m.mediaUrl!));

    if (isImage && m.mediaUrl != null) {
      final safeUrl = _BubbleValidators.sanitizeUrl(m.mediaUrl);
      if (safeUrl != null) {
        return _ImageBody(
          url: safeUrl,
          messageId: m.id,
          isViewOnce: m.isViewOnce,
          onViewed: widget.onViewOnceOpened,
        );
      }
    }

    if (m.mediaUrl != null && (m.mediaType == 'video' || m.mediaType == 'file')) {
      final safeUrl = _BubbleValidators.sanitizeUrl(m.mediaUrl);
      final safeName = _BubbleValidators.sanitize(m.mediaName ?? m.content, maxLength: _kMaxFileNameLength);
      if (safeUrl != null) {
        return _FileBody(type: m.mediaType ?? 'file', name: safeName, url: safeUrl, isOwn: widget.isOwn);
      }
    }

    final raw = m.content;
    if (_BubbleValidators.looksEncrypted(raw) && !_isDecrypted) {
      return _EncryptedBody(onUnlock: _unlock, isOwn: widget.isOwn);
    }

    final text = _isDecrypted ? (_decrypted ?? raw) : raw;
    final sanitized = _BubbleValidators.sanitize(text, maxLength: _kMaxContentLength);

    if (sanitized.trim().isEmpty && m.mediaUrl == null) return const SizedBox.shrink();

    return SelectableText(
      sanitized,
      style: TextStyle(color: _textColor, fontSize: 15, height: 1.35, fontWeight: FontWeight.w400),
    );
  }

  Future<void> _unlock() async {
    if (_isUnlocking) return;

    final l10n = AppLocalizations.of(context);
    HapticFeedback.mediumImpact();
    setState(() => _isUnlocking = true);

    final ctrl = TextEditingController();

    final password = await showDialog<String>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: ThixPolicy.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: ThixPolicy.border)),
          title: Row(
            children: [
              const Icon(Icons.lock_rounded, color: ThixPolicy.primary, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(_t(l10n, 'bubble_protected_message', 'Protected message'),
                    style: ThixPolicy.titleStyle.copyWith(fontWeight: ThixPolicy.bold)),
              ),
            ],
          ),
          content: TextField(
            controller: ctrl,
            obscureText: true,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onChanged: (_) => setDialogState(() {}),
            onSubmitted: (val) {
              if (val.trim().isNotEmpty) Navigator.pop(dialogCtx, val.trim());
            },
            decoration: InputDecoration(
              labelText: _t(l10n, 'bubble_password', 'Password'),
              hintText: _t(l10n, 'bubble_password_hint', 'Enter the password'),
              prefixIcon: const Icon(Icons.key_rounded, size: 18),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: ThixPolicy.primary, width: 1.5)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text(_t(l10n, 'common_cancel', 'Cancel')),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.primary, foregroundColor: Colors.white),
              onPressed: ctrl.text.trim().isEmpty ? null : () => Navigator.pop(dialogCtx, ctrl.text.trim()),
              child: Text(_t(l10n, 'bubble_unlock', 'Unlock')),
            ),
          ],
        ),
      ),
    );

    ctrl.dispose();
    if (!mounted) return;
    setState(() => _isUnlocking = false);

    if (password == null || password.isEmpty) return;

    try {
      final plain = EncryptionService.decryptMessage(m.content, password);
      if (plain == null || plain.isEmpty) throw Exception('Empty result');
      if (mounted) {
        setState(() {
          _isDecrypted = true;
          _decrypted = plain;
        });
        HapticFeedback.mediumImpact();
      }
    } catch (e) {
      debugPrint('[Bubble] ❌ Decrypt error: $e');
      if (mounted) {
        HapticFeedback.lightImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(_t(l10n, 'bubble_wrong_password', 'Wrong password'))),
            ]),
            backgroundColor: ThixPolicy.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _showEditDialog() async {
    final l10n = AppLocalizations.of(context);
    HapticFeedback.mediumImpact();

    final ctrl = TextEditingController(text: _isDecrypted ? _decrypted : m.content);

    final newContent = await showDialog<String>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: ThixPolicy.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: ThixPolicy.border)),
        title: Text(_t(l10n, 'bubble_edit_message', 'Edit message'),
            style: ThixPolicy.titleStyle.copyWith(fontSize: 16, fontWeight: ThixPolicy.bold)),
        content: TextField(
          controller: ctrl,
          maxLines: null,
          maxLength: _kMaxContentLength,
          keyboardType: TextInputType.multiline,
          textInputAction: TextInputAction.newline,
          decoration: InputDecoration(
            counterText: '',
            filled: true,
            fillColor: ThixPolicy.surfaceSoft,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text(_t(l10n, 'common_cancel', 'Cancel'), style: TextStyle(color: ThixPolicy.textMuted))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.primary, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(dialogCtx, ctrl.text.trim()),
            child: Text(_t(l10n, 'bubble_save', 'Save')),
          ),
        ],
      ),
    );

    ctrl.dispose();

    if (newContent != null && newContent.isNotEmpty && newContent != m.content) {
      final sanitized = _BubbleValidators.sanitize(newContent, maxLength: _kMaxContentLength);
      if (sanitized.isNotEmpty) widget.onEdit?.call(sanitized);
    }
  }

  /// Menu appui long. La suppression passe par UN seul point d'entrée (onDelete)
  /// géré par chat_screen : message éphémère → suppression directe sans popup ;
  /// message normal → feuille « pour moi / pour tous ».
  void _openActions() {
    final l10n = AppLocalizations.of(context);
    HapticFeedback.mediumImpact();

    showModalBottomSheet(
      context: context,
      backgroundColor: ThixPolicy.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: ThixPolicy.border, borderRadius: BorderRadius.circular(4))),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: _quickReactions
                      .map((r) => Semantics(
                            button: true,
                            label: '${_t(l10n, 'bubble_react_with', 'React with')} $r',
                            child: InkWell(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                Navigator.pop(ctx);
                                widget.onReaction?.call(r);
                              },
                              child: Text(r, style: const TextStyle(fontSize: 28)),
                            ),
                          ))
                      .toList(),
                ),
              ),
              const Divider(height: 1, color: ThixPolicy.border),
              _ActionTile(
                  icon: Icons.reply_rounded,
                  label: _t(l10n, 'bubble_reply', 'Reply'),
                  color: ThixPolicy.primary,
                  onTap: () {
                    Navigator.pop(ctx);
                    widget.onReply?.call();
                  }),
              if (widget.onForward != null)
                _ActionTile(
                    icon: Icons.forward_rounded,
                    label: _t(l10n, 'bubble_forward', 'Forward'),
                    color: ThixPolicy.textMain,
                    onTap: () {
                      Navigator.pop(ctx);
                      widget.onForward?.call();
                    }),
              _ActionTile(
                  icon: Icons.copy_rounded,
                  label: _t(l10n, 'bubble_copy', 'Copy'),
                  color: ThixPolicy.textMuted,
                  onTap: () {
                    Navigator.pop(ctx);
                    final textToCopy = _isDecrypted ? (_decrypted ?? '') : m.content;
                    Clipboard.setData(ClipboardData(text: _BubbleValidators.sanitize(textToCopy, maxLength: _kMaxContentLength)));
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(_t(l10n, 'bubble_copied', 'Copied')),
                        backgroundColor: ThixPolicy.success,
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(milliseconds: 800)));
                  }),
              if (widget.onPin != null)
                _ActionTile(
                    icon: m.isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                    label: m.isPinned ? _t(l10n, 'bubble_unpin', 'Unpin') : _t(l10n, 'bubble_pin', 'Pin'),
                    color: ThixPolicy.gold,
                    onTap: () {
                      Navigator.pop(ctx);
                      widget.onPin?.call();
                    }),
              if (widget.onStar != null)
                _ActionTile(
                    icon: m.isStarred ? Icons.star_rounded : Icons.star_outline_rounded,
                    label: m.isStarred ? _t(l10n, 'bubble_unstar', 'Remove from favorites') : _t(l10n, 'bubble_star', 'Add to favorites'),
                    color: ThixPolicy.primary,
                    onTap: () {
                      Navigator.pop(ctx);
                      widget.onStar?.call();
                    }),
              if (_canEdit)
                _ActionTile(
                    icon: Icons.edit_rounded,
                    label: _t(l10n, 'bubble_edit', 'Edit'),
                    color: ThixPolicy.textMain,
                    onTap: () {
                      Navigator.pop(ctx);
                      _showEditDialog();
                    }),
              if (widget.onDelete != null)
                _ActionTile(
                    icon: Icons.delete_outline,
                    label: _t(l10n, 'bubble_delete', 'Delete'),
                    color: ThixPolicy.danger,
                    onTap: () {
                      Navigator.pop(ctx);
                      widget.onDelete?.call();
                    }),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// ⏱️ MINUTEUR D'AUTO-DESTRUCTION (ROUGE)
// ============================================================================
class _EphemeralTimerWidget extends StatefulWidget {
  final ChatMessage message;
  final VoidCallback onTick;

  const _EphemeralTimerWidget({required this.message, required this.onTick});

  @override
  State<_EphemeralTimerWidget> createState() => _EphemeralTimerWidgetState();
}

class _EphemeralTimerWidgetState extends State<_EphemeralTimerWidget> {
  Timer? _ticker;
  int _remainingSeconds = 0;

  @override
  void initState() {
    super.initState();
    _updateRemaining();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      _updateRemaining();
      if (_remainingSeconds <= 0) {
        _ticker?.cancel();
        widget.onTick();
      }
    });
  }

  void _updateRemaining() {
    final msg = widget.message;
    if (msg.deleteAt != null) {
      _remainingSeconds = msg.deleteAt!.toUtc().difference(DateTime.now().toUtc()).inSeconds;
    } else if (msg.ephemeralDuration != null) {
      final expiresAt = msg.createdAt.add(Duration(seconds: msg.ephemeralDuration!));
      _remainingSeconds = expiresAt.toUtc().difference(DateTime.now().toUtc()).inSeconds;
    } else {
      _remainingSeconds = 0;
    }
    if (_remainingSeconds < 0) _remainingSeconds = 0;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_remainingSeconds <= 0) return const SizedBox.shrink();

    final minutes = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_remainingSeconds % 60).toString().padLeft(2, '0');

    // Pastille claire + texte rouge : lisible sur bulle bleue comme sur bulle claire.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ThixPolicy.danger.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer_outlined, size: 12, color: ThixPolicy.danger),
          const SizedBox(width: 3),
          Text('$minutes:$seconds',
              style: const TextStyle(fontSize: 10, color: ThixPolicy.danger, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

// ============================================================================
// ACTION TILE
// ============================================================================
class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionTile({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(label, style: TextStyle(color: color)),
        onTap: onTap,
      ),
    );
  }
}

// ============================================================================
// DELETED BUBBLE (supprimé pour tous)
// ============================================================================
class _DeletedBubble extends StatelessWidget {
  final bool isOwn;
  final bool isDeletedForAll;

  const _DeletedBubble({required this.isOwn, this.isDeletedForAll = false});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Align(
      alignment: isOwn ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: ThixPolicy.surfaceSoft,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ThixPolicy.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.block, size: 14, color: ThixPolicy.textMuted),
            const SizedBox(width: 6),
            Text(
              isDeletedForAll
                  ? _t(l10n, 'bubble_deleted_for_all', 'This message was deleted')
                  : _t(l10n, 'bubble_deleted', 'Message deleted'),
              style: ThixPolicy.captionStyle.copyWith(fontSize: 13, fontStyle: FontStyle.italic, color: ThixPolicy.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// REPLY QUOTE
// ============================================================================
class _ReplyQuote extends StatelessWidget {
  final ChatMessage message;
  final bool isOwn;
  const _ReplyQuote({required this.message, required this.isOwn});

  @override
  Widget build(BuildContext context) {
    final safeName = _BubbleValidators.sanitize(message.senderName, maxLength: _kMaxNameLength);
    final safeContent = _BubbleValidators.sanitize(message.content, maxLength: 200);
    final l10n = AppLocalizations.of(context);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: isOwn ? Colors.white : ThixPolicy.primary, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(safeName.isEmpty ? _t(l10n, 'bubble_message', 'Message') : safeName,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: isOwn ? Colors.white : ThixPolicy.primary)),
          Text(safeContent.isEmpty ? '—' : safeContent,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: isOwn ? Colors.white70 : ThixPolicy.textMuted)),
        ],
      ),
    );
  }
}

// ============================================================================
// ENCRYPTED BODY
// ============================================================================
class _EncryptedBody extends StatelessWidget {
  final VoidCallback onUnlock;
  final bool isOwn;
  const _EncryptedBody({required this.onUnlock, required this.isOwn});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final color = isOwn ? Colors.white : ThixPolicy.primary;

    return Semantics(
      button: true,
      label: _t(l10n, 'bubble_tap_to_unlock', 'Tap to unlock'),
      child: InkWell(
        onTap: onUnlock,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_rounded, size: 16, color: color),
            const SizedBox(width: 8),
            Flexible(
              child: Text(_t(l10n, 'bubble_protected_tap', 'Protected message, tap to open'),
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// IMAGE BODY (View Once)
// ============================================================================
class _ImageBody extends StatelessWidget {
  final String url;
  final String messageId;
  final bool isViewOnce;
  final VoidCallback? onViewed;

  const _ImageBody({required this.url, required this.messageId, this.isViewOnce = false, this.onViewed});

  @override
  Widget build(BuildContext context) {
    final tag = 'img_$messageId';
    return Semantics(
      button: true,
      label: _t(AppLocalizations.of(context), 'bubble_view_image', 'View image'),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          if (isViewOnce && onViewed != null) onViewed!();
          showFullscreenImageViewer(context, url: url, heroTag: tag, fileName: 'thix_$messageId.jpg');
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            children: [
              Hero(
                tag: tag,
                child: CachedNetworkImage(
                  imageUrl: url,
                  width: 240,
                  height: 180,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                      width: 240,
                      height: 180,
                      color: ThixPolicy.surfaceSoft,
                      child: const Center(
                          child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: ThixPolicy.primary)))),
                  errorWidget: (_, __, ___) => Container(
                      width: 180,
                      height: 120,
                      color: ThixPolicy.surfaceSoft,
                      child: const Icon(Icons.broken_image_outlined, color: ThixPolicy.textMuted)),
                ),
              ),
              if (isViewOnce)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                    child: const Icon(Icons.visibility_rounded, color: Colors.white, size: 16),
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
// FILE BODY
// ============================================================================
class _FileBody extends StatefulWidget {
  final String type;
  final String name;
  final String url;
  final bool isOwn;
  const _FileBody({required this.type, required this.name, required this.url, required this.isOwn});

  @override
  State<_FileBody> createState() => _FileBodyState();
}

class _FileBodyState extends State<_FileBody> {
  bool _isDownloading = false;

  Future<void> _download() async {
    if (_isDownloading) return;
    final l10n = AppLocalizations.of(context);
    HapticFeedback.mediumImpact();
    setState(() => _isDownloading = true);

    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(SnackBar(
        content: Row(children: [
          const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
          const SizedBox(width: 8),
          Expanded(child: Text(_t(l10n, 'bubble_downloading', 'Downloading…')))
        ]),
        backgroundColor: ThixPolicy.primary,
        behavior: SnackBarBehavior.floating));

    try {
      final path = await _bubbleRetry(() => MediaSaver.download(url: widget.url, fileName: widget.name), label: 'downloadFile');
      if (!mounted) return;
      if (path != null) {
        HapticFeedback.lightImpact();
        messenger.showSnackBar(SnackBar(
            content: Row(children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text('${_t(l10n, 'bubble_downloaded', 'Downloaded')}: $path'))
            ]),
            backgroundColor: ThixPolicy.success,
            behavior: SnackBarBehavior.floating));
      } else {
        messenger.showSnackBar(SnackBar(
            content: Row(children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(_t(l10n, 'bubble_download_failed', 'Download failed')))
            ]),
            backgroundColor: ThixPolicy.danger,
            behavior: SnackBarBehavior.floating));
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(
            content: Row(children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(_BubbleValidators.friendlyError(e)))
            ]),
            backgroundColor: ThixPolicy.danger,
            behavior: SnackBarBehavior.floating));
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final safeName = widget.name.isNotEmpty ? widget.name : widget.type;
    return Semantics(
      button: true,
      label: '${_t(AppLocalizations.of(context), 'bubble_download_file', 'Download file')}: $safeName',
      child: GestureDetector(
        onTap: _isDownloading ? null : _download,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: widget.isOwn ? Colors.white30 : ThixPolicy.border)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            _isDownloading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: ThixPolicy.primary))
                : Icon(widget.type == 'video' ? Icons.videocam_rounded : Icons.insert_drive_file_rounded,
                    size: 18, color: widget.isOwn ? Colors.white : ThixPolicy.primary),
            const SizedBox(width: 8),
            Flexible(
                child: Text(safeName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: widget.isOwn ? Colors.white : ThixPolicy.textMain))),
            const SizedBox(width: 8),
            if (!_isDownloading) Icon(Icons.download_rounded, size: 16, color: widget.isOwn ? Colors.white70 : ThixPolicy.primary),
          ]),
        ),
      ),
    );
  }
}

// ============================================================================
// REACTIONS CHIP
// ============================================================================
class _ReactionsChip extends StatelessWidget {
  final List<MessageReaction> reactions;
  const _ReactionsChip({required this.reactions});

  @override
  Widget build(BuildContext context) {
    final map = <String, int>{};
    for (final r in reactions) {
      final safe = _BubbleValidators.sanitize(r.reaction, maxLength: _kMaxReactionLength);
      if (safe.isNotEmpty) map[safe] = (map[safe] ?? 0) + 1;
    }
    if (map.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
          color: ThixPolicy.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ThixPolicy.border),
          boxShadow: ThixPolicy.shadowSoft(opacity: 0.06)),
      child: Row(
          mainAxisSize: MainAxisSize.min,
          children: map.entries
              .map((e) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Text(e.value > 1 ? '${e.key} ${e.value}' : e.key, style: const TextStyle(fontSize: 12))))
              .toList()),
    );
  }
}

// ============================================================================
// QUICK REACTIONS
// ============================================================================
class _QuickReactions extends StatelessWidget {
  final void Function(String) onPick;
  const _QuickReactions({required this.onPick});

  static const _reactions = ['❤️', '😂', '🔥', '👍', '😮', '😢'];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(color: ThixPolicy.card, borderRadius: BorderRadius.circular(24), boxShadow: ThixPolicy.shadowSoft(opacity: 0.08)),
      child: Row(
          mainAxisSize: MainAxisSize.min,
          children: _reactions
              .map((r) => Semantics(
                  button: true,
                  label: '${_t(l10n, 'bubble_react_with', 'React with')} $r',
                  child: InkWell(
                      onTap: () => onPick(r),
                      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: Text(r, style: const TextStyle(fontSize: 22))))))
              .toList()),
    );
  }
}

// ============================================================================
// MESSAGE STATUS TICKS
// ============================================================================
class MessageStatusTicks extends StatelessWidget {
  final bool isDelivered;
  final bool isRead;
  final Color color;

  const MessageStatusTicks({super.key, required this.isDelivered, required this.isRead, this.color = ThixPolicy.primary});

  @override
  Widget build(BuildContext context) {
    final activeColor = isRead ? ThixPolicy.success : (isDelivered ? ThixPolicy.warning : ThixPolicy.textMuted);
    return Container(
      width: 9,
      height: 20,
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      decoration: BoxDecoration(color: ThixPolicy.inkDeep, borderRadius: BorderRadius.circular(5)),
      child: Column(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        _dot(ThixPolicy.success, activeColor == ThixPolicy.success),
        _dot(ThixPolicy.warning, activeColor == ThixPolicy.warning),
        _dot(ThixPolicy.textMuted, activeColor == ThixPolicy.textMuted && !isDelivered && !isRead),
      ]),
    );
  }

  Widget _dot(Color base, bool active) => Container(
      width: 5, height: 5, decoration: BoxDecoration(shape: BoxShape.circle, color: active ? base : base.withOpacity(0.22)));
}
