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
import 'package:thix_id/presentation/chat/widgets/chat_ephemeral_timer.dart';
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
// CHAT MESSAGE BUBBLE
// ============================================================================
class ChatMessageBubble extends ConsumerStatefulWidget {
  final ChatMessage message;
  final bool isOwn;
  final VoidCallback? onReply;
  final void Function(String reaction)? onReaction;
  final VoidCallback? onDelete;
  final void Function(String newContent)? onEdit;
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
    this.onEdit,
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

    if (m.isDeleted) {
      return _DeletedBubble(isOwn: widget.isOwn);
    }

    final topSpacing = widget.isFirstInGroup ? 6.0 : 1.5;
    final bottomSpacing = widget.isLastInGroup ? 6.0 : 1.5;
    final tailRadius = widget.isLastInGroup ? 4.0 : 16.0;

    return Padding(
      padding: EdgeInsets.only(top: topSpacing, bottom: bottomSpacing),
      child: Column(
        crossAxisAlignment:
            widget.isOwn ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
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
              if (widget.onReaction != null) {
                widget.onReaction!('❤️');
              }
            },
            child: Align(
              alignment:
                  widget.isOwn ? Alignment.centerRight : Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * _kBubbleMaxWidthRatio,
                ),
                child: Stack(
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
                              if (m.isEphemeral || widget.isEphemeralActive) ...[
                                Builder(
                                  builder: (context) {
                                    int remainingSeconds = m.ephemeralDuration ?? 0;

                                    if (m.deleteAt != null) {
                                      remainingSeconds = m.deleteAt!
                                          .toUtc()
                                          .difference(DateTime.now().toUtc())
                                          .inSeconds;
                                    }

                                    if (remainingSeconds <= 0) {
                                      WidgetsBinding.instance.addPostFrameCallback((_) {
                                        widget.onDelete?.call();
                                      });
                                      return const SizedBox.shrink();
                                    }

                                    return ChatEphemeralTimer(
                                      duration: remainingSeconds,
                                      onExpired: () {
                                        widget.onDelete?.call();
                                      },
                                    );
                                  }
                                ),
                                const SizedBox(width: 6),
                              ],

                              if (m.sentiment != null && widget.isAgentView) ...[
                                SentimentIndicator(result: m.sentiment!),
                                const SizedBox(width: 6),
                              ],
                              Text(
                                DateFormat('HH:mm').format(m.createdAt.toLocal()),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: _timeColor,
                                ),
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

                    if (m.reactions.isNotEmpty)
                      Positioned(
                        bottom: -10,
                        right: widget.isOwn ? 16 : null,
                        left: widget.isOwn ? null : 16,
                        child: _ReactionsChip(reactions: m.reactions),
                      ),
                  ],
                ),
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

  Widget _buildBody(AppLocalizations l10n) {
    if (m.isCodeSnippet && (m.codeContent?.isNotEmpty ?? false)) {
      return ChatCodeSnippet(
        code: m.codeContent!,
        language: m.codeLanguage ?? 'text',
      );
    }

    if (m.mediaType == 'audio' && m.mediaUrl != null) {
      final safeUrl = _BubbleValidators.sanitizeUrl(m.mediaUrl);
      if (safeUrl != null) {
        return AudioPlayerWidget(audioUrl: safeUrl);
      }
    }

    final isImage = m.mediaType == 'image' ||
        (m.mediaUrl != null && _imageExtRegex.hasMatch(m.mediaUrl!));

    if (isImage && m.mediaUrl != null) {
      final safeUrl = _BubbleValidators.sanitizeUrl(m.mediaUrl);
      if (safeUrl != null) {
        return _ImageBody(url: safeUrl, messageId: m.id);
      }
    }

    if (m.mediaUrl != null &&
        (m.mediaType == 'video' || m.mediaType == 'file')) {
      final safeUrl = _BubbleValidators.sanitizeUrl(m.mediaUrl);
      final safeName = _BubbleValidators.sanitize(
        m.mediaName ?? m.content,
        maxLength: _kMaxFileNameLength,
      );
      if (safeUrl != null) {
        return _FileBody(
          type: m.mediaType ?? 'file',
          name: safeName,
          url: safeUrl,
          isOwn: widget.isOwn,
        );
      }
    }

    final raw = m.content;
    if (_BubbleValidators.looksEncrypted(raw) && !_isDecrypted) {
      return _EncryptedBody(onUnlock: _unlock, isOwn: widget.isOwn);
    }

    final text = _isDecrypted ? (_decrypted ?? raw) : raw;
    final sanitized = _BubbleValidators.sanitize(text, maxLength: _kMaxContentLength);

    if (sanitized.trim().isEmpty && m.mediaUrl == null) {
      return const SizedBox.shrink();
    }

    return SelectableText(
      sanitized,
      style: TextStyle(
        color: _textColor,
        fontSize: 15,
        height: 1.35,
        fontWeight: FontWeight.w400,
      ),
    );
  }

  Future<void> _unlock() async {
    if (_isUnlocking) {
      debugPrint('[Bubble] ⚠️ Unlock already in progress');
      return;
    }

    final l10n = AppLocalizations.of(context);
    HapticFeedback.mediumImpact();
    setState(() => _isUnlocking = true);

    final ctrl = TextEditingController();
    debugPrint('[Bubble] 🔐 Opening unlock dialog');

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: ThixPolicy.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: ThixPolicy.border),
        ),
        title: Text(
          l10n.t('bubble_protected_message'),
          style: ThixPolicy.titleStyle.copyWith(fontWeight: ThixPolicy.bold),
        ),
        content: Semantics(
          label: l10n.t('bubble_password_label'),
          textField: true,
          child: TextField(
            controller: ctrl,
            obscureText: true,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => Navigator.pop(dialogCtx, true),
            decoration: InputDecoration(
              labelText: l10n.t('bubble_password'),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.pop(dialogCtx, false);
            },
            child: Text(l10n.t('common_cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ThixPolicy.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              HapticFeedback.mediumImpact();
              Navigator.pop(dialogCtx, true);
            },
            child: Text(l10n.t('bubble_unlock')),
          ),
        ],
      ),
    ).then((result) {
      ctrl.dispose();
      debugPrint('[Bubble] 👋 Unlock dialog disposed');
      return result;
    });

    if (!mounted) {
      setState(() => _isUnlocking = false);
      return;
    }

    setState(() => _isUnlocking = false);

    if (ok != true) return;

    try {
      final plain = EncryptionService.decryptMessage(m.content, ctrl.text.trim());
      if (mounted) {
        setState(() {
          _isDecrypted = true;
          _decrypted = plain;
        });
        debugPrint('[Bubble] ✓ Message unlocked');
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

    final ctrl = TextEditingController(
      text: _isDecrypted ? _decrypted : m.content,
    );
    debugPrint('[Bubble] ✏️ Opening edit dialog');

    final newContent = await showDialog<String>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: ThixPolicy.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: ThixPolicy.border),
        ),
        title: Text(
          l10n.t('bubble_edit_message'),
          style: ThixPolicy.titleStyle.copyWith(
            fontSize: 16,
            fontWeight: ThixPolicy.bold,
          ),
        ),
        content: Semantics(
          label: l10n.t('bubble_edit_label'),
          textField: true,
          child: TextField(
            controller: ctrl,
            maxLines: null,
            maxLength: _kMaxContentLength,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            decoration: InputDecoration(
              counterText: '',
              filled: true,
              fillColor: ThixPolicy.surfaceSoft,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.pop(dialogCtx);
            },
            child: Text(
              l10n.t('common_cancel'),
              style: TextStyle(color: ThixPolicy.textMuted),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ThixPolicy.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              HapticFeedback.mediumImpact();
              Navigator.pop(dialogCtx, ctrl.text.trim());
            },
            child: Text(l10n.t('bubble_save')),
          ),
        ],
      ),
    ).then((result) {
      ctrl.dispose();
      debugPrint('[Bubble] 👋 Edit dialog disposed');
      return result;
    });

    if (newContent != null && newContent.isNotEmpty && newContent != m.content) {
      final sanitized = _BubbleValidators.sanitize(newContent, maxLength: _kMaxContentLength);
      if (sanitized.isNotEmpty) {
        widget.onEdit?.call(sanitized);
        debugPrint('[Bubble] ✓ Message edited');
      }
    }
  }

  void _openActions() {
    final l10n = AppLocalizations.of(context);
    HapticFeedback.mediumImpact();
    debugPrint('[Bubble] 📋 Opening actions menu');

    showModalBottomSheet(
      context: context,
      backgroundColor: ThixPolicy.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: ThixPolicy.border,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: _quickReactions
                    .map(
                      (r) => Semantics(
                        button: true,
                        label: '${l10n.t('bubble_react_with')} $r',
                        child: InkWell(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            Navigator.pop(ctx);
                            widget.onReaction?.call(r);
                          },
                          child: Text(r, style: const TextStyle(fontSize: 28)),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            const Divider(height: 1, color: ThixPolicy.border),
            Semantics(
              button: true,
              label: l10n.t('bubble_reply'),
              child: ListTile(
                leading: const Icon(Icons.reply_rounded, color: ThixPolicy.primary),
                title: Text(l10n.t('bubble_reply')),
                onTap: () {
                  HapticFeedback.selectionClick();
                  Navigator.pop(ctx);
                  widget.onReply?.call();
                },
              ),
            ),
            Semantics(
              button: true,
              label: l10n.t('bubble_copy'),
              child: ListTile(
                leading: const Icon(Icons.copy_rounded, color: ThixPolicy.textMuted),
                title: Text(l10n.t('bubble_copy')),
                onTap: () {
                  HapticFeedback.selectionClick();
                  final textToCopy = _isDecrypted ? (_decrypted ?? '') : m.content;
                  final sanitized = _BubbleValidators.sanitize(textToCopy, maxLength: _kMaxContentLength);
                  Clipboard.setData(ClipboardData(text: sanitized));
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(l10n.t('bubble_copied')),
                      backgroundColor: ThixPolicy.success,
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(milliseconds: 800),
                    ),
                  );
                },
              ),
            ),

            if (widget.isOwn && m.mediaUrl == null && !m.isDeleted)
              Semantics(
                button: true,
                label: l10n.t('bubble_edit'),
                child: ListTile(
                  leading: const Icon(Icons.edit_rounded, color: ThixPolicy.textMain),
                  title: Text(l10n.t('bubble_edit')),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showEditDialog();
                  },
                ),
              ),

            if (widget.isOwn)
              Semantics(
                button: true,
                label: l10n.t('bubble_delete'),
                child: ListTile(
                  leading: const Icon(Icons.delete_outline, color: ThixPolicy.danger),
                  title: Text(
                    l10n.t('bubble_delete'),
                    style: const TextStyle(color: ThixPolicy.danger),
                  ),
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    Navigator.pop(ctx);
                    widget.onDelete?.call();
                  },
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// DELETED BUBBLE
// ============================================================================
class _DeletedBubble extends StatelessWidget {
  final bool isOwn;
  const _DeletedBubble({required this.isOwn});

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
              l10n.t('bubble_deleted'),
              style: ThixPolicy.captionStyle.copyWith(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: ThixPolicy.textMuted,
              ),
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
    final safeContent = _BubbleValidators.sanitize(
      message.content,
      maxLength: 200,
    );
    final l10n = AppLocalizations.of(context);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(color: isOwn ? Colors.white : ThixPolicy.primary, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            safeName.isEmpty ? l10n.t('bubble_message') : safeName,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: isOwn ? Colors.white : ThixPolicy.primary,
            ),
          ),
          Text(
            safeContent.isEmpty ? '—' : safeContent,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: isOwn ? Colors.white70 : ThixPolicy.textMuted,
            ),
          ),
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
            Flexible(
              child: Text(
                l10n.t('bubble_protected_tap'),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color,
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
// IMAGE BODY
// ============================================================================
class _ImageBody extends StatelessWidget {
  final String url;
  final String messageId;
  const _ImageBody({required this.url, required this.messageId});

  @override
  Widget build(BuildContext context) {
    final tag = 'img_$messageId';
    return Semantics(
      button: true,
      label: AppLocalizations.of(context).t('bubble_view_image'),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          showFullscreenImageViewer(
            context,
            url: url,
            heroTag: tag,
            fileName: 'thix_$messageId.jpg',
          );
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Hero(
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
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: ThixPolicy.primary,
                    ),
                  ),
                ),
              ),
              errorWidget: (_, __, ___) => Container(
                width: 180,
                height: 120,
                color: ThixPolicy.surfaceSoft,
                child: const Icon(Icons.broken_image_outlined, color: ThixPolicy.textMuted),
              ),
            ),
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

  const _FileBody({
    required this.type,
    required this.name,
    required this.url,
    required this.isOwn,
  });

  @override
  State<_FileBody> createState() => _FileBodyState();
}

class _FileBodyState extends State<_FileBody> {
  bool _isDownloading = false;

  Future<void> _download() async {
    if (_isDownloading) {
      debugPrint('[Bubble] ⚠️ Download already in progress');
      return;
    }

    final l10n = AppLocalizations.of(context);
    HapticFeedback.mediumImpact();
    setState(() => _isDownloading = true);

    final messenger = ScaffoldMessenger.of(context);
    debugPrint('[Bubble] ⬇️ Downloading file: ${widget.name}');

    messenger.showSnackBar(
      SnackBar(
        content: Row(children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(l10n.t('bubble_downloading'))),
        ]),
        backgroundColor: ThixPolicy.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );

    try {
      final path = await _bubbleRetry(
        () => MediaSaver.download(url: widget.url, fileName: widget.name),
        label: 'downloadFile',
      );

      if (!mounted) return;

      if (path != null) {
        HapticFeedback.lightImpact();
        messenger.showSnackBar(
          SnackBar(
            content: Row(children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text('${l10n.t('bubble_downloaded')}: $path')),
            ]),
            backgroundColor: ThixPolicy.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        debugPrint('[Bubble] ✓ File downloaded to: $path');
      } else {
        HapticFeedback.lightImpact();
        messenger.showSnackBar(
          SnackBar(
            content: Row(children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(l10n.t('bubble_download_failed'))),
            ]),
            backgroundColor: ThixPolicy.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('[Bubble] ❌ Download error: $e');
      if (mounted) {
        HapticFeedback.lightImpact();
        messenger.showSnackBar(
          SnackBar(
            content: Row(children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(_BubbleValidators.friendlyError(e))),
            ]),
            backgroundColor: ThixPolicy.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
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
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: widget.isOwn ? Colors.white30 : ThixPolicy.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _isDownloading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: ThixPolicy.primary,
                      ),
                    )
                  : Icon(
                      widget.type == 'video'
                          ? Icons.videocam_rounded
                          : Icons.insert_drive_file_rounded,
                      size: 18,
                      color: widget.isOwn ? Colors.white : ThixPolicy.primary,
                    ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  safeName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: widget.isOwn ? Colors.white : ThixPolicy.textMain,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (!_isDownloading)
                Icon(
                  Icons.download_rounded,
                  size: 16,
                  color: widget.isOwn ? Colors.white70 : ThixPolicy.primary,
                ),
            ],
          ),
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
      if (safe.isNotEmpty) {
        map[safe] = (map[safe] ?? 0) + 1;
      }
    }

    if (map.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: ThixPolicy.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ThixPolicy.border),
        boxShadow: ThixPolicy.shadowSoft(opacity: 0.06),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: map.entries
            .map(
              (e) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Text(
                  e.value > 1 ? '${e.key} ${e.value}' : e.key,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            )
            .toList(),
      ),
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
      decoration: BoxDecoration(
        color: ThixPolicy.card,
        borderRadius: BorderRadius.circular(24),
        boxShadow: ThixPolicy.shadowSoft(opacity: 0.08),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: _reactions
            .map(
              (r) => Semantics(
                button: true,
                label: '${AppLocalizations.of(context).t('bubble_react_with')} $r',
                child: InkWell(
                  onTap: () => onPick(r),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(r, style: const TextStyle(fontSize: 22)),
                  ),
                ),
              ),
            )
            .toList(),
      ),
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

  const MessageStatusTicks({
    super.key,
    required this.isDelivered,
    required this.isRead,
    this.color = ThixPolicy.primary,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = isRead
        ? ThixPolicy.success
        : (isDelivered ? ThixPolicy.warning : ThixPolicy.textMuted);

    return Container(
      width: 9,
      height: 20,
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      decoration: BoxDecoration(
        color: ThixPolicy.inkDeep,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _dot(ThixPolicy.success, activeColor == ThixPolicy.success),
          _dot(ThixPolicy.warning, activeColor == ThixPolicy.warning),
          _dot(ThixPolicy.textMuted, activeColor == ThixPolicy.textMuted && !isDelivered && !isRead),
        ],
      ),
    );
  }

  Widget _dot(Color base, bool active) {
    return Container(
      width: 5,
      height: 5,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? base : base.withOpacity(0.22),
      ),
    );
  }
}
