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

// ============================================================================
// VALIDATORS
// ============================================================================
class _BubbleValidators {
  _BubbleValidators._();

  static String sanitize(String? input, {int maxLength = 500}) {
    if (input == null || input.trim().isEmpty) return '';
    final doc = html_parser.parse(input);
    var s = doc.body?.text ?? input;
    s = s
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'javascript:', caseSensitive: false), '')
        .replaceAll(RegExp(r'on\w+\s*=', caseSensitive: false), '')
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        .trim();
    return s.length > maxLength ? s.substring(0, maxLength) : s;
  }

  static String? sanitizeUrl(String? url) {
    if (url == null || url.trim().isEmpty) return null;
    final t = url.trim();
    if (!t.startsWith('http://') && !t.startsWith('https://')) return null;
    return t.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
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
      debugPrint('[Bubble] ⏱️ $label timeout — retry $attempt/$maxRetries');
      await Future.delayed(_kRetryDelay);
    } catch (e) {
      debugPrint('[Bubble] ❌ $label error: $e');
      rethrow;
    }
  }
}

// ============================================================================
// CHAT MESSAGE BUBBLE (P0/P1 Enterprise)
// ============================================================================
class ChatMessageBubble extends ConsumerStatefulWidget {
  final ChatMessage message;
  final bool isOwn;
  final VoidCallback? onReply;
  final void Function(String reaction)? onReaction;
  final VoidCallback? onDelete;
  final VoidCallback? onDeleteForAll; // ✅ P0: Supprimer pour tous
  final void Function(String newContent)? onEdit;
  final VoidCallback? onForward;     // ✅ P0: Transférer
  final VoidCallback? onPin;         // ✅ P0: Épingler
  final VoidCallback? onStar;        // ✅ P0: Favori
  final VoidCallback? onViewOnceOpened; // ✅ P1: View Once
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

  bool get _shouldHideNote {
    if (!_isNote) return false;
    return !widget.isAgentView;
  }

  // ✅ P0: Vérification fenêtre d'édition (15 min)
  bool get _canEdit {
    if (!widget.isOwn) return false;
    if (m.isDeleted || m.isDeletedForAll) return false;
    if (m.hasMedia) return false;
    if (m.isEphemeral) return false;
    final elapsed = DateTime.now().toUtc().difference(m.createdAt);
    return elapsed.inMinutes <= _kEditWindowMinutes;
  }

  // ✅ P0: Vérification fenêtre suppression pour tous (15 min)
  bool get _canDeleteForAll {
    if (!widget.isOwn) return false;
    if (m.isDeleted || m.isDeletedForAll) return false;
    final elapsed = DateTime.now().toUtc().difference(m.createdAt);
    return elapsed.inMinutes <= _kEditWindowMinutes;
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

    // ✅ CORRECTION AUTO-DESTRUCT: Si expiré, ne rien afficher du tout
    if (m.isExpired || m.isDeleted || m.isDeletedForAll) {
      return _DeletedBubble(isOwn: widget.isOwn, isDeletedForAll: m.isDeletedForAll);
    }

    // ✅ P1: View Once déjà vu → masquer
    if (m.isViewOnce && m.hasBeenViewed) {
      return const SizedBox.shrink();
    }

    final topSpacing = widget.isFirstInGroup ? 6.0 : 1.5;
    final bottomSpacing = widget.isLastInGroup ? 6.0 : 1.5;
    final tailRadius = widget.isLastInGroup ? 4.0 : 16.0;

    // ✅ P0: Swipe-to-Reply (seulement pour messages des autres)
    Widget bubbleContent = _buildBubbleContent(l10n, tailRadius);

    if (!widget.isOwn && widget.onReply != null) {
      bubbleContent = Dismissible(
        key: ValueKey(m.id),
        direction: DismissDirection.startToEnd,
        confirmDismiss: (_) async => false, // On gère manuellement
        onUpdate: (details) {
          // Feedback haptique au seuil de 30%
          if (details.progress > 0.3 && details.previousProgress <= 0.3) {
            HapticFeedback.selectionClick();
          }
        },
        onDismissed: (_) {
          widget.onReply?.call();
        },
        child: bubbleContent,
      );
    }

    return Padding(
      padding: EdgeInsets.only(top: topSpacing, bottom: bottomSpacing),
      child: Column(
        crossAxisAlignment:
            widget.isOwn ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // ✅ P0: Badge Forward
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
                    l10n.t('bubble_forwarded'),
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
                    l10n.t('bubble_internal_note'),
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
              alignment:
                  widget.isOwn ? Alignment.centerRight : Alignment.centerLeft,
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
                _ReplyQuote(
                  message: widget.replyToMessage!,
                  isOwn: widget.isOwn,
                ),

              _buildBody(l10n),

              const SizedBox(height: 4),

              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // ✅ P0: Badge "Modifié"
                  if (m.isEdited) ...[
                    Text(
                      l10n.t('bubble_edited'),
                      style: TextStyle(fontSize: 9, color: _timeColor, fontStyle: FontStyle.italic),
                    ),
                    const SizedBox(width: 4),
                  ],

                  // ✅ CORRECTION AUTO-DESTRUCT: Timer visuel actif avec StreamBuilder
                  if (m.isEphemeral || widget.isEphemeralActive) ...[
                    _EphemeralTimerWidget(
                      message: m,
                      timeColor: _timeColor,
                      onExpired: () {
                        // Force le rebuild parent pour masquer le message
                        if (mounted) setState(() {});
                        widget.onDelete?.call();
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
                    MessageStatusTicks(
                      isDelivered: m.isDelivered,
                      isRead: m.isRead,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),

        // ✅ P0: Badge Épinglé
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

        // ✅ P0: Badge Favori
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

    // ✅ P1: View Once media
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

  // ✅ CORRECTION MOT DE PASSE: Dialog robuste avec validation
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
              Expanded(child: Text(l10n.t('bubble_protected_message'), style: ThixPolicy.titleStyle.copyWith(fontWeight: ThixPolicy.bold))),
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
              labelText: l10n.t('bubble_password'),
              hintText: l10n.t('bubble_password_hint'),
              prefixIcon: const Icon(Icons.key_rounded, size: 18),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: ThixPolicy.primary, width: 1.5)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text(l10n.t('common_cancel')),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.primary, foregroundColor: Colors.white),
              onPressed: ctrl.text.trim().isEmpty ? null : () => Navigator.pop(dialogCtx, ctrl.text.trim()),
              child: Text(l10n.t('bubble_unlock')),
            ),
          ],
        ),
      ),
    );

    ctrl.dispose();
    if (!mounted) { setState(() => _isUnlocking = false); return; }
    setState(() => _isUnlocking = false);

    if (password == null || password.isEmpty) return;

    try {
      final plain = EncryptionService.decryptMessage(m.content, password);
      if (plain == null || plain.isEmpty) throw Exception('Empty result');
      if (mounted) {
        setState(() { _isDecrypted = true; _decrypted = plain; });
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
              Expanded(child: Text(l10n.t('bubble_wrong_password'))),
            ]),
            backgroundColor: ThixPolicy.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showEditDialog() async {
    final l10n = AppLocalizations.of(context);
    HapticFeedback.mediumImpact();

    final ctrl = TextEditingController(text: _isDecrypted ? _decrypted : m.content);

    final newContent = await showDialog<String>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: ThixPolicy.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: ThixPolicy.border)),
        title: Text(l10n.t('bubble_edit_message'), style: ThixPolicy.titleStyle.copyWith(fontSize: 16, fontWeight: ThixPolicy.bold)),
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
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: Text(l10n.t('common_cancel'), style: TextStyle(color: ThixPolicy.textMuted))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.primary, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(dialogCtx, ctrl.text.trim()),
            child: Text(l10n.t('bubble_save')),
          ),
        ],
      ),
    );

    ctrl.dispose();

    if (newContent != null && newContent.isNotEmpty && newContent != m.content) {
      final sanitized = _BubbleValidators.sanitize(newContent, maxLength: _kMaxContentLength);
      if (sanitized.isNotEmpty) {
        widget.onEdit?.call(sanitized);
      }
    }
  }

  // ✅ MENU CONTEXTUEL COMPLET P0/P1
  void _openActions() {
    final l10n = AppLocalizations.of(context);
    HapticFeedback.mediumImpact();

    showModalBottomSheet(
      context: context,
      backgroundColor: ThixPolicy.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: ThixPolicy.border, borderRadius: BorderRadius.circular(4))),
            
            // Quick Reactions
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: _quickReactions.map((r) => Semantics(
                  button: true,
                  label: '${l10n.t('bubble_react_with')} $r',
                  child: InkWell(
                    onTap: () { HapticFeedback.selectionClick(); Navigator.pop(ctx); widget.onReaction?.call(r); },
                    child: Text(r, style: const TextStyle(fontSize: 28)),
                  ),
                )).toList(),
              ),
            ),
            const Divider(height: 1, color: ThixPolicy.border),

            // Reply
            _ActionTile(icon: Icons.reply_rounded, label: l10n.t('bubble_reply'), color: ThixPolicy.primary,
              onTap: () { Navigator.pop(ctx); widget.onReply?.call(); }),

            // ✅ P0: Forward
            if (widget.onForward != null)
              _ActionTile(icon: Icons.forward_rounded, label: l10n.t('bubble_forward'), color: ThixPolicy.textMain,
                onTap: () { Navigator.pop(ctx); widget.onForward?.call(); }),

            // Copy
            _ActionTile(icon: Icons.copy_rounded, label: l10n.t('bubble_copy'), color: ThixPolicy.textMuted,
              onTap: () {
                Navigator.pop(ctx);
                final textToCopy = _isDecrypted ? (_decrypted ?? '') : m.content;
                Clipboard.setData(ClipboardData(text: _BubbleValidators.sanitize(textToCopy, maxLength: _kMaxContentLength)));
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.t('bubble_copied')), backgroundColor: ThixPolicy.success, behavior: SnackBarBehavior.floating, duration: const Duration(milliseconds: 800)));
              }),

            // ✅ P0: Pin
            if (widget.onPin != null)
              _ActionTile(icon: m.isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                label: m.isPinned ? l10n.t('bubble_unpin') : l10n.t('bubble_pin'),
                color: ThixPolicy.gold,
                onTap: () { Navigator.pop(ctx); widget.onPin?.call(); }),

            // ✅ P0: Star
            if (widget.onStar != null)
              _ActionTile(icon: m.isStarred ? Icons.star_rounded : Icons.star_outline_rounded,
                label: m.isStarred ? l10n.t('bubble_unstar') : l10n.t('bubble_star'),
                color: ThixPolicy.primary,
                onTap: () { Navigator.pop(ctx); widget.onStar?.call(); }),

            // ✅ P0: Edit (15 min window)
            if (_canEdit)
              _ActionTile(icon: Icons.edit_rounded, label: l10n.t('bubble_edit'), color: ThixPolicy.textMain,
                onTap: () { Navigator.pop(ctx); _showEditDialog(); }),

            // ✅ P0: Delete for All (15 min window)
            if (_canDeleteForAll && widget.onDeleteForAll != null)
              _ActionTile(icon: Icons.delete_forever_rounded, label: l10n.t('bubble_delete_for_all'), color: ThixPolicy.danger,
                onTap: () { Navigator.pop(ctx); widget.onDeleteForAll?.call(); }),

            // Delete for Me
            if (widget.onDelete != null)
              _ActionTile(icon: Icons.delete_outline, label: l10n.t('bubble_delete'), color: ThixPolicy.danger,
                onTap: () { Navigator.pop(ctx); widget.onDelete?.call(); }),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// ✅ CORRECTION AUTO-DESTRUCT: Timer visuel actif avec StreamBuilder
// ============================================================================
class _EphemeralTimerWidget extends StatefulWidget {
  final ChatMessage message;
  final Color timeColor;
  final VoidCallback onExpired;

  const _EphemeralTimerWidget({required this.message, required this.timeColor, required this.onExpired});

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
    // Tick toutes les secondes pour mise à jour visuelle fluide
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      _updateRemaining();
      if (_remainingSeconds <= 0) {
        _ticker?.cancel();
        widget.onExpired();
      }
    });
  }

  void _updateRemaining() {
    if (widget.message.deleteAt != null) {
      _remainingSeconds = widget.message.deleteAt!.toUtc().difference(DateTime.now().toUtc()).inSeconds;
    } else if (widget.message.ephemeralDuration != null) {
      final expiresAt = widget.message.createdAt.add(Duration(seconds: widget.message.ephemeralDuration!));
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

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.timer_outlined, size: 12, color: widget.timeColor),
        const SizedBox(width: 3),
        Text('$minutes:$seconds', style: TextStyle(fontSize: 10, color: widget.timeColor, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

// ============================================================================
// ACTION TILE (Menu contextuel)
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
// DELETED BUBBLE
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
            Icon(isDeletedForAll ? Icons.block : Icons.block, size: 14, color: ThixPolicy.textMuted),
            const SizedBox(width: 6),
            Text(
              isDeletedForAll ? l10n.t('bubble_deleted_for_all') : l10n.t('bubble_deleted'),
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
          Text(safeName.isEmpty ? l10n.t('bubble_message') : safeName,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: isOwn ? Colors.white : ThixPolicy.primary)),
          Text(safeContent.isEmpty ? '—' : safeContent, maxLines: 2, overflow: TextOverflow.ellipsis,
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
      label: l10n.t('bubble_tap_to_unlock'),
      child: InkWell(
        onTap: onUnlock,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_rounded, size: 16, color: color),
            const SizedBox(width: 8),
            Flexible(child: Text(l10n.t('bubble_protected_tap'), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color))),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// IMAGE BODY (avec View Once support)
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
      label: AppLocalizations.of(context).t('bubble_view_image'),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          // ✅ P1: Marquer comme vu pour View Once
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
                  placeholder: (_, __) => Container(width: 240, height: 180, color: ThixPolicy.surfaceSoft,
                    child: const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: ThixPolicy.primary)))),
                  errorWidget: (_, __, ___) => Container(width: 180, height: 120, color: ThixPolicy.surfaceSoft,
                    child: const Icon(Icons.broken_image_outlined, color: ThixPolicy.textMuted)),
                ),
              ),
              // ✅ P1: Badge View Once
              if (isViewOnce)
                Positioned(
                  top: 8, right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
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
      content: Row(children: [const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)), const SizedBox(width: 8), Expanded(child: Text(l10n.t('bubble_downloading')))]),
      backgroundColor: ThixPolicy.primary, behavior: SnackBarBehavior.floating));

    try {
      final path = await _bubbleRetry(() => MediaSaver.download(url: widget.url, fileName: widget.name), label: 'downloadFile');
      if (!mounted) return;
      if (path != null) {
        HapticFeedback.lightImpact();
        messenger.showSnackBar(SnackBar(content: Row(children: [const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18), const SizedBox(width: 8), Expanded(child: Text('${l10n.t('bubble_downloaded')}: $path'))]), backgroundColor: ThixPolicy.success, behavior: SnackBarBehavior.floating));
      } else {
        messenger.showSnackBar(SnackBar(content: Row(children: [const Icon(Icons.error_outline_rounded, color: Colors.white, size: 18), const SizedBox(width: 8), Expanded(child: Text(l10n.t('bubble_download_failed')))]), backgroundColor: ThixPolicy.danger, behavior: SnackBarBehavior.floating));
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Row(children: [const Icon(Icons.error_outline_rounded, color: Colors.white, size: 18), const SizedBox(width: 8), Expanded(child: Text(_BubbleValidators.friendlyError(e)))]), backgroundColor: ThixPolicy.danger, behavior: SnackBarBehavior.floating));
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
      label: '${AppLocalizations.of(context).t('bubble_download_file')}: $safeName',
      child: GestureDetector(
        onTap: _isDownloading ? null : _download,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.black.withOpacity(0.06), borderRadius: BorderRadius.circular(10), border: Border.all(color: widget.isOwn ? Colors.white30 : ThixPolicy.border)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            _isDownloading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: ThixPolicy.primary))
                : Icon(widget.type == 'video' ? Icons.videocam_rounded : Icons.insert_drive_file_rounded, size: 18, color: widget.isOwn ? Colors.white : ThixPolicy.primary),
            const SizedBox(width: 8),
            Flexible(child: Text(safeName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: widget.isOwn ? Colors.white : ThixPolicy.textMain))),
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
      decoration: BoxDecoration(color: ThixPolicy.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: ThixPolicy.border), boxShadow: ThixPolicy.shadowSoft(opacity: 0.06)),
      child: Row(mainAxisSize: MainAxisSize.min, children: map.entries.map((e) => Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: Text(e.value > 1 ? '${e.key} ${e.value}' : e.key, style: const TextStyle(fontSize: 12)))).toList()),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(color: ThixPolicy.card, borderRadius: BorderRadius.circular(24), boxShadow: ThixPolicy.shadowSoft(opacity: 0.08)),
      child: Row(mainAxisSize: MainAxisSize.min, children: _reactions.map((r) => Semantics(button: true, label: '${AppLocalizations.of(context).t('bubble_react_with')} $r', child: InkWell(onTap: () => onPick(r), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: Text(r, style: const TextStyle(fontSize: 22)))))).toList()),
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
      width: 9, height: 20, padding: const EdgeInsets.symmetric(vertical: 2.5),
      decoration: BoxDecoration(color: ThixPolicy.inkDeep, borderRadius: BorderRadius.circular(5)),
      child: Column(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        _dot(ThixPolicy.success, activeColor == ThixPolicy.success),
        _dot(ThixPolicy.warning, activeColor == ThixPolicy.warning),
        _dot(ThixPolicy.textMuted, activeColor == ThixPolicy.textMuted && !isDelivered && !isRead),
      ]),
    );
  }

  Widget _dot(Color base, bool active) => Container(width: 5, height: 5, decoration: BoxDecoration(shape: BoxShape.circle, color: active ? base : base.withOpacity(0.22)));
}
