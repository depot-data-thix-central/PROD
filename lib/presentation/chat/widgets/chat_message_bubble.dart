// lib/presentation/chat/widgets/chat_message_bubble.dart
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/models/chat/chat_message.dart';
import 'package:thix_id/presentation/chat/encryption_service.dart';
import 'package:thix_id/presentation/chat/widgets/chat_common.dart';
import 'package:thix_id/presentation/chat/widgets/image_viewer.dart';
import 'package:thix_id/presentation/thix_market/core/african_currencies.dart';
import 'package:thix_id/presentation/thix_market/core/chat_service.dart' as market_chat;
import 'package:thix_id/presentation/thix_market/core/currency_service.dart';
import 'package:thix_id/presentation/thix_market/providers/currency_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
// ============================================================================
// HELPERS
// ============================================================================
Map<String, dynamic> _safeJson(ChatMessage m) {
  try {
    return Map<String, dynamic>.from(m.toJson());
  } catch (_) {
    return const <String, dynamic>{};
  }
}

Map<String, int> _reactionsOf(Map<String, dynamic> j) {
  final out = <String, int>{};
  try {
    final r = j['reactions'];
    if (r is Map) {
      r.forEach((k, v) {
        final n = v is List ? v.length : (v is num ? v.toInt() : 1);
        if (n > 0) out['$k'] = n;
      });
    } else if (r is List) {
      for (final e in r) {
        String? emoji;
        if (e is Map) {
          emoji = (e['reaction'] ?? e['emoji'])?.toString();
        } else if (e is String) {
          emoji = e;
        }
        if (emoji != null && emoji.isNotEmpty) out[emoji] = (out[emoji] ?? 0) + 1;
      }
    }
  } catch (_) {}
  return out;
}

const List<Color> _namePalette = [
  Color(0xFFB5651D), Color(0xFF2E7D32), Color(0xFF8E24AA),
  Color(0xFFC62828), Color(0xFF00796B), Color(0xFFAD1457),
];
Color _nameColor(String s) => _namePalette[s.hashCode.abs() % _namePalette.length];

bool _isJumboEmoji(String s) {
  final t = s.trim();
  if (t.isEmpty || t.length > 16) return false;
  final runes = t.runes.toList();
  if (runes.length > 6) return false;
  return runes.every((r) => r > 0x2000);
}

/// ✅ Préfixe des messages chiffrés par mot de passe
const String _kEncPrefix = 'ENCv1:';
bool _isEncryptedText(String s) => s.trimLeft().startsWith(_kEncPrefix);

/// ✅ Ouverture de lien : compatible Web (url_launcher 6.3.x) + fallback clipboard
Future<void> _openExternal(BuildContext context, String? raw) async {
  final u = ChatValidators.sanitizeUrl(raw);
  if (u == null) {
    if (context.mounted) chatSnack(context, 'Média indisponible ou lien expiré', ChatSnackKind.warning);
    return;
  }
  try {
    if (kIsWeb) {
      // url_launcher 6.3.x : webOnlyWindowName est un String ("_blank" = nouvel onglet)
      await launchUrl(Uri.parse(u), webOnlyWindowName: '_blank');
    } else {
      await launchUrl(Uri.parse(u), mode: LaunchMode.externalApplication);
    }
  } catch (_) {
    try {
      await launchUrl(Uri.parse(u));
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: u));
      if (context.mounted) chatSnack(context, 'Lien copié dans le presse-papiers', ChatSnackKind.info);
    }
  }
}

// ============================================================================
// AVATAR
// ============================================================================
class _SmallAvatar extends StatelessWidget {
  final String? url;
  final double size;
  const _SmallAvatar({this.url, this.size = 28});
  @override
  Widget build(BuildContext context) {
    final safe = ChatValidators.sanitizeUrl(url);
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: ThixPolicy.tint,
      backgroundImage: safe != null ? CachedNetworkImageProvider(safe) : null,
      child: safe == null ? Icon(Icons.person, size: size * 0.6, color: ThixPolicy.textSecondary) : null,
    );
  }
}

// ============================================================================
// TEXTE AVEC LIENS CLIQUABLES
// ============================================================================
class _LinkText extends StatefulWidget {
  final String text;
  final TextStyle style;
  const _LinkText({required this.text, required this.style});
  @override
  State<_LinkText> createState() => _LinkTextState();
}

class _LinkTextState extends State<_LinkText> {
  static final RegExp _urlRe = RegExp(r'(https?:\/\/[^\s]+|www\.[^\s]+)', caseSensitive: false);
  final List<TapGestureRecognizer> _recs = [];

  void _clear() {
    for (final r in _recs) {
      r.dispose();
    }
    _recs.clear();
  }

  @override
  void dispose() {
    _clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _clear();
    final text = widget.text;
    if (!text.contains('http') && !text.contains('www.')) return Text(text, style: widget.style);
    final spans = <InlineSpan>[];
    int last = 0;
    for (final m in _urlRe.allMatches(text)) {
      if (m.start > last) spans.add(TextSpan(text: text.substring(last, m.start)));
      var url = m.group(0)!;
      var trailing = '';
      while (url.isNotEmpty && '.,;:!?)'.contains(url[url.length - 1])) {
        trailing = url[url.length - 1] + trailing;
        url = url.substring(0, url.length - 1);
      }
      final rec = TapGestureRecognizer()
        ..onTap = () => _openExternal(context, url.startsWith('www.') ? 'https://$url' : url);
      _recs.add(rec);
      spans.add(TextSpan(
        text: url,
        style: const TextStyle(decoration: TextDecoration.underline, fontWeight: FontWeight.w600),
        recognizer: rec,
      ));
      if (trailing.isNotEmpty) spans.add(TextSpan(text: trailing));
      last = m.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
    return Text.rich(TextSpan(style: widget.style, children: spans));
  }
}

// ============================================================================
// BULLE MESSAGE PRINCIPALE
// ============================================================================
/// isFirstInGroup = HAUT visuel du groupe (affiche le nom)
/// isLastInGroup  = BAS visuel du groupe (affiche l'avatar + queue de bulle)
class ChatMessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isOwn;
  final VoidCallback? onReply;
  final void Function(String reaction)? onReaction;
  final VoidCallback? onDelete;
  final VoidCallback? onDeleteForAll;
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
  final String? senderName;
  final String? senderAvatarUrl;
  final bool showSender;

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
    this.senderName,
    this.senderAvatarUrl,
    this.showSender = true,
  });

  @override
  Widget build(BuildContext context) {
    final m = message;
    if (isInternalNote && !isAgentView) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final json = _safeJson(m);
    final deleted = m.isDeleted || m.isDeletedForAll;
    final type = '${m.mediaType ?? ''}';
    final maxW = MediaQuery.of(context).size.width * 0.76;
    final text = m.content;
    final jumbo = !deleted && type.isEmpty && _isJumboEmoji(text) && replyToMessage == null && !m.isForwarded;
    final isSticker = !deleted && type == 'sticker';
    final bare = jumbo || isSticker;
    final reactions = deleted ? const <String, int>{} : _reactionsOf(json);

    final children = <Widget>[];

    if (!isOwn && showSender && isFirstInGroup && (senderName ?? '').isNotEmpty && !bare) {
      children.add(Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(ChatValidators.sanitize(senderName, maxLength: 40),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _nameColor(senderName ?? ''))),
      ));
    }

    if (isInternalNote && isAgentView) {
      children.add(Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.lock_rounded, size: 11, color: ThixPolicy.gold),
          const SizedBox(width: 4),
          Text(chatTr(l10n, 'chat_internal_note', 'Note interne'),
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: ThixPolicy.gold)),
        ]),
      ));
    }

    if (m.isForwarded && !deleted) {
      children.add(Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.forward_rounded, size: 12, color: ThixPolicy.textMuted),
          const SizedBox(width: 4),
          Text(chatTr(l10n, 'chat_forwarded', 'Transféré'),
              style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: ThixPolicy.textMuted)),
        ]),
      ));
    }

    if (replyToMessage != null && !deleted) {
      final r = replyToMessage!;
      children.add(Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(8, 5, 8, 5),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
          border: const Border(left: BorderSide(color: ThixPolicy.gold, width: 3)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(ChatValidators.sanitize(r.senderName, maxLength: 30),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _nameColor(r.senderName))),
          // ✅ Aperçu propre (masque ENCv1: et PRODUCT_REF:)
          Text(ChatValidators.sanitize(chatPreviewOf(r), maxLength: 80),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: ThixPolicy.textSecondary)),
        ]),
      ));
    }

    children.addAll(_body(context, l10n, type, deleted, jumbo, maxW));

    // ✅ COMPTE À REBOURS ÉPHÉMÈRE
    if (m.isEphemeral && !deleted && (m.ephemeralDuration ?? 0) > 0) {
      children.add(Padding(
        padding: const EdgeInsets.only(top: 6),
        child: EphemeralCountdown(expiresAt: m.createdAt.add(Duration(seconds: m.ephemeralDuration!))),
      ));
    }

    // Méta (heure, ticks…)
    if (!isSticker) {
      children.add(Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Align(alignment: Alignment.centerRight, child: _meta(json, deleted)),
      ));
    }

    Widget bubble;
    if (isSticker) {
      bubble = Column(crossAxisAlignment: isOwn ? CrossAxisAlignment.end : CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        ...children,
        _meta(json, deleted),
      ]);
    } else if (jumbo) {
      bubble = Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: children);
    } else {
      const r16 = Radius.circular(16);
      const r4 = Radius.circular(4);
      bubble = Container(
        padding: const EdgeInsets.fromLTRB(10, 7, 10, 5),
        decoration: BoxDecoration(
          color: isInternalNote ? ThixPolicy.gold.withOpacity(0.18) : (isOwn ? kOwnBubbleColor : kOtherBubbleColor),
          borderRadius: BorderRadius.only(
            topLeft: r16,
            topRight: r16,
            bottomLeft: isOwn ? r16 : (isLastInGroup ? r4 : r16),
            bottomRight: isOwn ? (isLastInGroup ? r4 : r16) : r16,
          ),
          border: Border.all(color: ThixPolicy.border.withOpacity(0.45), width: 0.8),
          boxShadow: ThixPolicy.shadowSoft(opacity: 0.035),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: children),
      );
    }

    Widget withReactions = Column(
      crossAxisAlignment: isOwn ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        bubble,
        if (reactions.isNotEmpty)
          Transform.translate(
            offset: const Offset(0, -4),
            child: Wrap(
              spacing: 4,
              children: reactions.entries
                  .map((e) => GestureDetector(
                        onTap: () => onReaction?.call(e.key),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: ThixPolicy.border),
                          ),
                          child: Text(e.value > 1 ? '${e.key} ${e.value}' : e.key, style: const TextStyle(fontSize: 12)),
                        ),
                      ))
                  .toList(),
            ),
          ),
      ],
    );

    final showAvatar = !isOwn && showSender;
    return Padding(
      padding: EdgeInsets.only(top: isFirstInGroup ? 6 : 1.5, bottom: 1.5),
      child: Row(
        mainAxisAlignment: isOwn ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (showAvatar)
            SizedBox(width: 32, child: isLastInGroup ? _SmallAvatar(url: senderAvatarUrl, size: 26) : null),
          Flexible(child: ConstrainedBox(constraints: BoxConstraints(maxWidth: maxW), child: withReactions)),
        ],
      ),
    );
  }

  String _formatMetaTime(DateTime date) {
    final now = DateTime.now();
    if (chatSameDay(date, now)) {
      return DateFormat('HH:mm').format(date);
    } else if (chatSameDay(date, now.subtract(const Duration(days: 1)))) {
      return 'Hier ${DateFormat('HH:mm').format(date)}';
    } else {
      return '${DateFormat('dd/MM').format(date)} ${DateFormat('HH:mm').format(date)}';
    }
  }

  Widget _meta(Map<String, dynamic> json, bool deleted) {
    final m = message;
    final edited = json['is_edited'] == true && !deleted;
    final muted = ThixPolicy.textMuted;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      if (m.isPinned) Padding(padding: const EdgeInsets.only(right: 3), child: Icon(Icons.push_pin_rounded, size: 11, color: muted)),
      if (m.isStarred) const Padding(padding: EdgeInsets.only(right: 3), child: Icon(Icons.star_rounded, size: 11, color: ThixPolicy.gold)),
      if (isEphemeralActive) Padding(padding: const EdgeInsets.only(right: 3), child: Icon(Icons.timer_outlined, size: 11, color: muted)),
      if (edited) Padding(padding: const EdgeInsets.only(right: 4), child: Text('modifié', style: TextStyle(fontSize: 10, color: muted, fontStyle: FontStyle.italic))),
      Text(_formatMetaTime(m.createdAt.toLocal()), style: TextStyle(fontSize: 10, color: muted)),
      if (isOwn && !deleted) ...[
        const SizedBox(width: 3),
        Icon(m.isRead || m.isDelivered ? Icons.done_all_rounded : Icons.done_rounded,
            size: 14, color: m.isRead ? ThixPolicy.success : muted),
      ],
    ]);
  }

  List<Widget> _body(BuildContext context, AppLocalizations l10n, String type, bool deleted, bool jumbo, double maxW) {
    final m = message;
    final textStyle = const TextStyle(fontSize: 15, height: 1.4, color: ThixPolicy.textMain);

    if (deleted) {
      return [
        Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.block_rounded, size: 14, color: ThixPolicy.textMuted),
          const SizedBox(width: 6),
          Text(chatTr(l10n, 'chat_message_deleted', 'Message supprimé'),
              style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: ThixPolicy.textMuted)),
        ]),
      ];
    }

    final url = ChatValidators.sanitizeUrl(m.mediaUrl);
    final name = ChatValidators.sanitize(m.mediaName, maxLength: 60);
    final caption = m.content.trim();
    final hasCaption = caption.isNotEmpty && caption != (m.mediaName ?? '') && !caption.startsWith('🎤');

    Widget? captionWidget() => hasCaption
        ? Padding(padding: const EdgeInsets.only(top: 6), child: _LinkText(text: caption, style: textStyle))
        : null;

    switch (type) {
      case 'sticker':
        return [
          url == null
              ? const Icon(Icons.broken_image_outlined, color: ThixPolicy.textSecondary)
              : CachedNetworkImage(
                  imageUrl: url,
                  width: 140,
                  height: 140,
                  fit: BoxFit.contain,
                  errorWidget: (_, __, ___) => const Icon(Icons.broken_image_outlined, color: ThixPolicy.textSecondary)),
        ];

      case 'image':
        {
          final unseenOnce = m.isViewOnce && !m.hasBeenViewed;
          if (unseenOnce) {
            return [
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: isOwn || url == null
                    ? null
                    : () {
                        HapticFeedback.selectionClick();
                        onViewOnceOpened?.call();
                        showFullscreenImageViewer(context, url: url, heroTag: 'once_${m.id}', fileName: m.mediaName ?? 'thix_${m.id}.jpg');
                      },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(color: ThixPolicy.surfaceSoft, borderRadius: BorderRadius.circular(12)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.visibility_rounded, size: 20, color: ThixPolicy.inkDeep),
                    const SizedBox(width: 8),
                    Text(isOwn ? chatTr(l10n, 'chat_view_once_sent', 'Photo à usage unique') : chatTr(l10n, 'chat_view_once_tap', 'Photo à usage unique · Ouvrir'),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: ThixPolicy.textMain)),
                  ]),
                ),
              ),
            ];
          }
          return [
            GestureDetector(
              onTap: url == null
                  ? null
                  : () => showFullscreenImageViewer(context, url: url, heroTag: 'img_${m.id}', fileName: m.mediaName ?? 'thix_${m.id}.jpg'),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: url == null
                    ? const SizedBox(width: 200, height: 120, child: Center(child: Icon(Icons.broken_image_outlined, color: ThixPolicy.textSecondary)))
                    : CachedNetworkImage(
                        imageUrl: url,
                        width: 230,
                        height: 230,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                            width: 230,
                            height: 230,
                            color: ThixPolicy.tint,
                            child: const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: ThixPolicy.inkDeep)))),
                        errorWidget: (_, __, ___) => const SizedBox(width: 230, height: 120, child: Center(child: Icon(Icons.broken_image_outlined, color: ThixPolicy.textSecondary))),
                      ),
              ),
            ),
            if (captionWidget() != null) captionWidget()!,
          ];
        }

      case 'audio':
        return [
          SizedBox(
            width: 230,
            child: url == null
                ? const Text('Audio indisponible', style: TextStyle(color: ThixPolicy.textMuted))
                : ChatWaveformAudioPlayer(audioUrl: url, onDark: false),
          ),
        ];

      case 'video':
      case 'file':
        {
          final ext = ChatValidators.extOfName(m.mediaName);
          final icon = type == 'video' ? Icons.videocam_rounded : ChatValidators.iconForExtension(ext);
          return [
            InkWell(
              borderRadius: BorderRadius.circular(12),
              // ✅ Sur Web : nouvel onglet ; si URL invalide : snackbar au lieu de rien
              onTap: () {
                if (url == null) {
                  chatSnack(context, chatTr(l10n, 'chat_media_unavailable', 'Média indisponible ou expiré'), ChatSnackKind.warning);
                  return;
                }
                _openExternal(context, url);
              },
              child: Container(
                width: 230,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.black.withOpacity(0.045), borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(color: ThixPolicy.inkDeep, borderRadius: BorderRadius.circular(10)),
                    child: Icon(icon, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(name.isEmpty ? (type == 'video' ? 'Vidéo' : 'Fichier') : name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: ThixPolicy.textMain)),
                      if (ChatValidators.formatSize(m.mediaSize).isNotEmpty)
                        Text(ChatValidators.formatSize(m.mediaSize), style: const TextStyle(fontSize: 11, color: ThixPolicy.textMuted)),
                    ]),
                  ),
                  Icon(type == 'video' ? Icons.play_circle_outline_rounded : Icons.download_rounded, color: ThixPolicy.textSecondary, size: 22),
                ]),
              ),
            ),
            if (captionWidget() != null) captionWidget()!,
          ];
        }
    }

    // 🔐 MESSAGE PROTÉGÉ PAR MOT DE PASSE (ENCv1:…)
    if (type.isEmpty && _isEncryptedText(m.content)) {
      return [_ProtectedMessageBox(message: m, textStyle: textStyle)];
    }

    // Texte
    if (jumbo) return [Text(m.content.trim(), style: const TextStyle(fontSize: 44))];
    return [_LinkText(text: m.content, style: textStyle)];
  }
}

// ============================================================================
// MESSAGE PROTÉGÉ (ENCv1:) — déblocage par mot de passe
// ============================================================================
class _ProtectedMessageBox extends StatefulWidget {
  final ChatMessage message;
  final TextStyle textStyle;
  const _ProtectedMessageBox({required this.message, required this.textStyle});
  @override
  State<_ProtectedMessageBox> createState() => _ProtectedMessageBoxState();
}

class _ProtectedMessageBoxState extends State<_ProtectedMessageBox> {
  String? _plain;
  bool _unlocking = false;

  Future<void> _unlock() async {
    final l10n = AppLocalizations.of(context);
    final ctrl = TextEditingController();
    final pwd = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThixPolicy.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          const Icon(Icons.lock_outline_rounded, color: ThixPolicy.gold, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(chatTr(l10n, 'chat_pwd_enter', 'Mot de passe du message'),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: ThixPolicy.textMain)),
          ),
        ]),
        content: TextField(
          controller: ctrl,
          obscureText: true,
          autofocus: true,
          decoration: InputDecoration(labelText: chatTr(l10n, 'chat_password', 'Mot de passe')),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(chatTr(l10n, 'common_cancel', 'Annuler'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.inkDeep),
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('OK', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (pwd == null || pwd.isEmpty || !mounted) return;
    setState(() => _unlocking = true);
    try {
      final String? plain = EncryptionService.decryptMessage(widget.message.content, pwd);
      if (!mounted) return;
      if (plain == null || plain.isEmpty) throw StateError('decrypt');
      setState(() {
        _plain = plain;
        _unlocking = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _unlocking = false);
      chatSnack(context, chatTr(l10n, 'chat_pwd_bad', 'Mot de passe incorrect'), ChatSnackKind.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_plain != null) return _LinkText(text: _plain!, style: widget.textStyle);
    return InkWell(
      onTap: _unlocking ? null : _unlock,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: ThixPolicy.gold.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ThixPolicy.gold.withOpacity(0.5)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          _unlocking
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: ThixPolicy.gold))
              : const Icon(Icons.lock_rounded, size: 18, color: ThixPolicy.gold),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              chatTr(l10n, 'chat_protected_tap', 'Message protégé · toucher pour ouvrir'),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: ThixPolicy.textMain),
            ),
          ),
        ]),
      ),
    );
  }
}

// ============================================================================
// COMPTE À REBOURS ÉPHÉMÈRE
// ============================================================================
class EphemeralCountdown extends StatefulWidget {
  final DateTime expiresAt;
  const EphemeralCountdown({super.key, required this.expiresAt});
  @override
  State<EphemeralCountdown> createState() => _EphemeralCountdownState();
}

class _EphemeralCountdownState extends State<EphemeralCountdown> {
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
    final left = widget.expiresAt.difference(DateTime.now());
    if (left.isNegative) return const SizedBox.shrink();
    final s = left.inSeconds;
    final label = s >= 60 ? '${s ~/ 60} min ${s % 60}s' : '${s}s';
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: ThixPolicy.gold.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.timer_outlined, size: 11, color: ThixPolicy.gold),
          const SizedBox(width: 3),
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: ThixPolicy.gold)),
        ]),
      ),
    );
  }
}

// ============================================================================
// MESSAGE EN ATTENTE (envoi optimiste)
// ============================================================================
class PendingMessage {
  final String localId;
  final String kind; // text | image | video | audio | file | sticker
  final String label;
  final DateTime createdAt;
  final Uint8List? previewBytes;
  bool failed;
  final Future<ChatMessage?> Function() job;

  PendingMessage({
    required this.kind,
    required this.label,
    required this.job,
    this.previewBytes,
  })  : localId = 'local_${DateTime.now().microsecondsSinceEpoch}',
        createdAt = DateTime.now(),
        failed = false;
}

class PendingBubble extends StatelessWidget {
  final PendingMessage message;
  final VoidCallback onRetry;
  final VoidCallback onCancel;
  const PendingBubble({super.key, required this.message, required this.onRetry, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    final p = message;
    final maxW = MediaQuery.of(context).size.width * 0.76;
    final media = (p.kind == 'image' || p.kind == 'sticker') && p.previewBytes != null;
    IconData icon = Icons.insert_drive_file_rounded;
    if (p.kind == 'audio') icon = Icons.mic_rounded;
    if (p.kind == 'video') icon = Icons.videocam_rounded;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Align(
        alignment: Alignment.centerRight,
        child: GestureDetector(
          onTap: p.failed ? onRetry : null,
          onLongPress: p.failed ? onCancel : null,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxW),
            child: Opacity(
              opacity: p.failed ? 1 : 0.88,
              child: Container(
                padding: const EdgeInsets.fromLTRB(10, 7, 10, 5),
                decoration: BoxDecoration(
                  color: kOwnBubbleColor,
                  borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16), topRight: Radius.circular(16), bottomLeft: Radius.circular(16), bottomRight: Radius.circular(4)),
                  border: Border.all(color: p.failed ? ThixPolicy.danger.withOpacity(0.6) : ThixPolicy.border.withOpacity(0.45), width: 0.8),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  if (media)
                    ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.memory(p.previewBytes!, width: 170, height: 170, fit: BoxFit.cover))
                  else if (p.kind == 'text')
                    Text(p.label, style: const TextStyle(fontSize: 15, height: 1.3, color: ThixPolicy.textMain))
                  else
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(icon, size: 20, color: ThixPolicy.inkDeep),
                      const SizedBox(width: 8),
                      Flexible(child: Text(p.label, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ThixPolicy.textMain))),
                    ]),
                  const SizedBox(height: 3),
                  Align(
                    alignment: Alignment.centerRight,
                    child: p.failed
                        ? Row(mainAxisSize: MainAxisSize.min, children: const [
                            Icon(Icons.error_outline_rounded, size: 13, color: ThixPolicy.danger),
                            SizedBox(width: 4),
                            Text('Échec · toucher pour réessayer', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: ThixPolicy.danger)),
                          ])
                        : Row(mainAxisSize: MainAxisSize.min, children: [
                            Text(DateFormat('HH:mm').format(p.createdAt), style: const TextStyle(fontSize: 10, color: ThixPolicy.textMuted)),
                            const SizedBox(width: 3),
                            const Icon(Icons.schedule_rounded, size: 12, color: ThixPolicy.textMuted),
                          ]),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// SÉPARATEURS / SYSTÈME
// ============================================================================
class DateSeparator extends StatelessWidget {
  final DateTime date;
  const DateSeparator({super.key, required this.date});
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final now = DateTime.now();
    final d = date.toLocal();
    String label;
    if (chatSameDay(d, now)) {
      label = chatTr(l10n, 'chat_today', 'Aujourd’hui');
    } else if (chatSameDay(d, now.subtract(const Duration(days: 1)))) {
      label = chatTr(l10n, 'chat_yesterday', 'Hier');
    } else {
      label = DateFormat('dd/MM/yyyy').format(d);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.92), borderRadius: BorderRadius.circular(12), border: Border.all(color: ThixPolicy.border.withOpacity(0.6))),
          child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: ThixPolicy.textSecondary)),
        ),
      ),
    );
  }
}

class SystemBubble extends StatelessWidget {
  final String text;
  final IconData icon;
  const SystemBubble({super.key, required this.text, this.icon = Icons.screenshot_rounded});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: ThixPolicy.gold.withOpacity(0.16), borderRadius: BorderRadius.circular(14)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 14, color: ThixPolicy.textSecondary),
            const SizedBox(width: 6),
            Flexible(child: Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ThixPolicy.textSecondary))),
          ]),
        ),
      ),
    );
  }
}

class UnreadDivider extends StatelessWidget {
  final AppLocalizations l10n;
  const UnreadDivider({super.key, required this.l10n});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(children: [
        Expanded(child: Container(height: 1, color: ThixPolicy.inkDeep.withOpacity(0.25))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(chatTr(l10n, 'chat_new_messages', 'Nouveaux messages'),
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: ThixPolicy.textSecondary)),
        ),
        Expanded(child: Container(height: 1, color: ThixPolicy.inkDeep.withOpacity(0.25))),
      ]),
    );
  }
}

class ViewOnceOpenedBubble extends StatelessWidget {
  final bool isOwn;
  final bool isSender;
  const ViewOnceOpenedBubble({super.key, required this.isOwn, required this.isSender});
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Align(
        alignment: isOwn ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: isOwn ? kOwnBubbleColor : kOtherBubbleColor, borderRadius: BorderRadius.circular(14), border: Border.all(color: ThixPolicy.border.withOpacity(0.6))),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.visibility_off_rounded, size: 14, color: ThixPolicy.textMuted),
            const SizedBox(width: 6),
            Text(
              isSender ? chatTr(l10n, 'chat_viewonce_opened_sender', 'Média ouvert par le destinataire') : chatTr(l10n, 'chat_viewonce_opened', 'Média à usage unique ouvert'),
              style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textMuted, fontStyle: FontStyle.italic),
            ),
          ]),
        ),
      ),
    );
  }
}

class TypingPill extends StatelessWidget {
  final AppLocalizations l10n;
  const TypingPill({super.key, required this.l10n});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(color: ThixPolicy.card, borderRadius: BorderRadius.circular(20), border: Border.all(color: ThixPolicy.border), boxShadow: ThixPolicy.shadowSoft(opacity: 0.03)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const _Dot(),
        const SizedBox(width: 3),
        const _Dot(delay: 120),
        const SizedBox(width: 3),
        const _Dot(delay: 240),
        const SizedBox(width: 8),
        Text(chatTr(l10n, 'chat_typing', 'écrit…'), style: ThixPolicy.captionStyle.copyWith(fontSize: 12, color: ThixPolicy.textSecondary, fontStyle: FontStyle.italic, fontWeight: FontWeight.w500)),
      ]),
    );
  }
}

class _Dot extends StatefulWidget {
  final int delay;
  const _Dot({this.delay = 0});
  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  Timer? _t;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    if (widget.delay > 0) {
      _t = Timer(Duration(milliseconds: widget.delay), () {
        if (mounted) _c.repeat(reverse: true);
      });
    } else {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _t?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _c,
        child: Container(width: 5, height: 5, decoration: const BoxDecoration(color: ThixPolicy.inkDeep, shape: BoxShape.circle)),
      );
}

class ReplyBanner extends StatelessWidget {
  final String text;
  final VoidCallback onClose;
  const ReplyBanner({super.key, required this.text, required this.onClose});
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: ThixPolicy.card, border: Border(top: BorderSide(color: ThixPolicy.border))),
      child: Row(children: [
        Container(width: 4, height: 36, decoration: BoxDecoration(color: ThixPolicy.gold, borderRadius: BorderRadius.circular(4))),
        const SizedBox(width: 12),
        Expanded(child: Text(text.isEmpty ? '—' : text, maxLines: 1, overflow: TextOverflow.ellipsis, style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.textSecondary, fontSize: 13))),
        IconButton(icon: const Icon(Icons.close_rounded, size: 20, color: ThixPolicy.textSecondary), onPressed: onClose, tooltip: chatTr(l10n, 'common_close', 'Fermer')),
      ]),
    );
  }
}

/// Bouton « descendre » avec compteur de nouveaux messages
class ChatScrollDownButton extends StatelessWidget {
  final int count;
  final VoidCallback onTap;
  const ChatScrollDownButton({super.key, required this.count, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Stack(clipBehavior: Clip.none, children: [
      Material(
        color: Colors.white,
        elevation: 3,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: const SizedBox(width: 42, height: 42, child: Icon(Icons.keyboard_arrow_down_rounded, color: ThixPolicy.inkDeep, size: 28)),
        ),
      ),
      if (count > 0)
        Positioned(
          top: -6,
          right: -2,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: ThixPolicy.inkDeep, borderRadius: BorderRadius.circular(10)),
            child: Text(count > 99 ? '99+' : '$count', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
          ),
        ),
    ]);
  }
}

// ============================================================================
// APPEL / GROUPE D'IMAGES / PAGER / PRODUIT
// ============================================================================
class CallBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isOwn;
  final VoidCallback onCallback;
  const CallBubble({super.key, required this.message, required this.isOwn, required this.onCallback});
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isVideo = message.mediaType == 'call_video';
    final lower = message.content.toLowerCase();
    final isMissed = lower.contains('manqué') || lower.contains('missed') || lower.contains('sans réponse');
    final Color dirColor = isMissed ? ThixPolicy.danger : (isOwn ? ThixPolicy.success : ThixPolicy.inkDeep);
    final IconData dirIcon = isMissed ? Icons.call_missed_rounded : (isOwn ? Icons.call_made_rounded : Icons.call_received_rounded);
    final String dirLabel = isMissed
        ? chatTr(l10n, 'chat_call_missed', 'Appel manqué')
        : (isOwn ? chatTr(l10n, 'chat_call_outgoing', 'Appel sortant') : chatTr(l10n, 'chat_call_incoming', 'Appel entrant'));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Align(
        alignment: isOwn ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: EdgeInsets.only(left: isOwn ? 50 : 0, right: isOwn ? 0 : 50),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: isOwn ? kOwnBubbleColor : kOtherBubbleColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: isMissed ? ThixPolicy.danger.withOpacity(0.3) : ThixPolicy.border), boxShadow: ThixPolicy.shadowSoft(opacity: 0.03)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: isMissed ? ThixPolicy.danger.withOpacity(0.1) : Colors.black.withOpacity(0.05), shape: BoxShape.circle),
              child: Icon(isVideo ? Icons.videocam_rounded : Icons.call_rounded, color: dirColor, size: 18),
            ),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(dirIcon, size: 14, color: dirColor),
                const SizedBox(width: 4),
                Text(dirLabel, style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.bold, fontSize: 14, color: isMissed ? ThixPolicy.danger : ThixPolicy.textMain)),
              ]),
              const SizedBox(height: 2),
              Text(DateFormat('HH:mm').format(message.createdAt.toLocal()), style: ThixPolicy.captionStyle.copyWith(fontSize: 11, color: ThixPolicy.textSecondary, fontWeight: FontWeight.w500)),
            ]),
            const SizedBox(width: 16),
            Semantics(
              button: true,
              label: chatTr(l10n, 'chat_callback', 'Rappeler'),
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  onCallback();
                },
                child: Container(padding: const EdgeInsets.all(8), decoration: const BoxDecoration(color: ThixPolicy.surfaceSoft, shape: BoxShape.circle), child: const Icon(Icons.refresh_rounded, size: 20, color: ThixPolicy.inkDeep)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class ImageGroupBubble extends StatelessWidget {
  final List<ChatMessage> images;
  final bool isOwn;
  final void Function(List<ChatMessage>, int)? onOpenGallery;
  const ImageGroupBubble({super.key, required this.images, required this.isOwn, this.onOpenGallery});
  @override
  Widget build(BuildContext context) {
    final shown = images.take(4).toList();
    final extra = images.length - shown.length;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Align(
        alignment: isOwn ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: EdgeInsets.only(left: isOwn ? 40 : 34, right: isOwn ? 4 : 40),
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(color: isOwn ? kOwnBubbleColor : kOtherBubbleColor, borderRadius: BorderRadius.circular(14), border: Border.all(color: ThixPolicy.border.withOpacity(0.6)), boxShadow: ThixPolicy.shadowSoft(opacity: 0.04)),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: shown.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 3, crossAxisSpacing: 3, childAspectRatio: 1),
                  itemBuilder: (context, idx) {
                    final msg = shown[idx];
                    final showMore = extra > 0 && idx == shown.length - 1;
                    final safeUrl = ChatValidators.sanitizeUrl(msg.mediaUrl);
                    return GestureDetector(
                      onTap: onOpenGallery != null
                          ? () => onOpenGallery!(images, idx)
                          : (safeUrl != null ? () => showFullscreenImageViewer(context, url: safeUrl, heroTag: 'img_${msg.id}', fileName: msg.mediaName ?? 'thix_${msg.id}.jpg') : null),
                      child: Stack(fit: StackFit.expand, children: [
                        safeUrl != null
                            ? CachedNetworkImage(
                                imageUrl: safeUrl,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => Container(color: ThixPolicy.tint, child: const Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: ThixPolicy.inkDeep)))),
                                errorWidget: (_, __, ___) => const Center(child: Icon(Icons.broken_image_outlined, color: ThixPolicy.textSecondary)),
                              )
                            : const Center(child: Icon(Icons.broken_image_outlined, color: ThixPolicy.textSecondary)),
                        if (showMore) Container(color: Colors.black.withOpacity(0.55), alignment: Alignment.center, child: Text('+ $extra', style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800))),
                      ]),
                    );
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 2, right: 6, bottom: 1),
              child: Text(DateFormat('HH:mm').format(images.first.createdAt.toLocal()), style: const TextStyle(fontSize: 10, color: ThixPolicy.textMuted)),
            ),
          ]),
        ),
      ),
    );
  }
}

class PhotoPager extends StatefulWidget {
  final List<ChatMessage> images;
  final int initialIndex;
  const PhotoPager({super.key, required this.images, required this.initialIndex});
  @override
  State<PhotoPager> createState() => _PhotoPagerState();
}

class _PhotoPagerState extends State<PhotoPager> {
  late final PageController _ctrl;
  int _idx = 0;
  bool _downloading = false;

  @override
  void initState() {
    super.initState();
    _idx = widget.initialIndex.clamp(0, widget.images.length - 1);
    _ctrl = PageController(initialPage: _idx);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _downloadImage(String url) async {
    if (_downloading) return;
    setState(() => _downloading = true);
    final l10n = AppLocalizations.of(context);
    try {
      if (kIsWeb) {
        // Sur le Web : ouvre l'image dans un nouvel onglet
        await launchUrl(Uri.parse(url), webOnlyWindowName: '_blank');
      } else {
        // Sur Mobile : Téléchargement
        final response = await HttpClient().getUrl(Uri.parse(url)).then((req) => req.close());
        final bytes = await consolidateHttpClientResponseBytes(response);
        
        final dir = await getApplicationDocumentsDirectory();
        final fileName = 'THIX_IMG_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final file = File(p.join(dir.path, fileName));
        await file.writeAsBytes(bytes);

        if (mounted) {
          chatSnack(context, '✅ Image enregistrée : ${file.path}', ChatSnackKind.success);
        }
      }
    } catch (e) {
      if (mounted) {
        chatSnack(context, 'Erreur lors du téléchargement : $e', ChatSnackKind.error);
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUrl = ChatValidators.sanitizeUrl(widget.images[_idx].mediaUrl);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text('${_idx + 1}/${widget.images.length}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        centerTitle: true,
        actions: [
          if (currentUrl != null)
            _downloading
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                  )
                : IconButton(
                    icon: const Icon(Icons.download_rounded),
                    tooltip: 'Télécharger',
                    onPressed: () => _downloadImage(currentUrl),
                  ),
        ],
      ),
      body: PageView.builder(
        controller: _ctrl,
        itemCount: widget.images.length,
        onPageChanged: (i) => setState(() => _idx = i),
        itemBuilder: (ctx, i) {
          final url = ChatValidators.sanitizeUrl(widget.images[i].mediaUrl);
          if (url == null) return const Center(child: Icon(Icons.broken_image_outlined, color: Colors.white54, size: 48));
          return InteractiveViewer(
            child: Center(
              child: CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.contain,
                placeholder: (_, __) => const Center(child: CircularProgressIndicator(color: Colors.white)),
                errorWidget: (_, __, ___) => const Icon(Icons.broken_image_outlined, color: Colors.white54, size: 48),
              ),
            ),
          );
        },
      ),
    );
  }
}

class ProductRefBubble extends ConsumerWidget {
  final market_chat.ProductRef product;
  final bool isOwn;
  final DateTime time;
  final bool isRead;
  final VoidCallback onLongPress;

  const ProductRefBubble({
    super.key,
    required this.product,
    required this.isOwn,
    required this.time,
    required this.isRead,
    required this.onLongPress,
  });

  static final RegExp _idRegex = RegExp(r'^[0-9a-fA-F-]{8,}$');

  static String _normCurrency(String raw) {
    final v = raw.toUpperCase().trim();
    if (AfricanCurrencies.byCode(v) != null) return v;
    const aliases = <String, String>{'FC': 'CDF', 'FCFA': 'XOF', r'$': 'USD', 'DOLLAR': 'USD', 'US': 'USD', 'EURO': 'EUR', '€': 'EUR'};
    return aliases[v] ?? 'CDF';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final displayCode = ref.watch(currencyProvider);
    final lang = Localizations.localeOf(context).languageCode;
    final from = _normCurrency(product.currencyCode);
    final isConverted = from != displayCode;

    var priceText = '';
    final price = product.price;
    if (price != null) {
      try {
        final service = CurrencyService.instance;
        final converted = service.convert(price, from: from, to: displayCode);
        priceText = service.formatPrice(converted, currencyCode: displayCode, lang: lang);
      } catch (_) {
        priceText = '';
      }
    }

    final title = ChatValidators.sanitize(product.title, maxLength: 80);
    final imageUrl = ChatValidators.sanitizeUrl(product.imageUrl);
    final canOpen = _idRegex.hasMatch(product.id);
    final label = chatTr(l10n, 'chat_product_ref', 'Référence produit');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Align(
        alignment: isOwn ? Alignment.centerRight : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: isOwn ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 3, left: 4, right: 4),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.shopping_bag_outlined, size: 11, color: ThixPolicy.textSecondary),
                const SizedBox(width: 4),
                Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: ThixPolicy.textSecondary)),
              ]),
            ),
            Semantics(
              button: canOpen,
              label: '$label ${title.isEmpty ? '' : title}',
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: canOpen
                    ? () {
                        HapticFeedback.selectionClick();
                        context.push('/market/product/${product.id}');
                      }
                    : null,
                onLongPress: () {
                  HapticFeedback.selectionClick();
                  onLongPress();
                },
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.74,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: isOwn ? kOwnBubbleColor : kOtherBubbleColor, borderRadius: BorderRadius.circular(14), border: Border.all(color: ThixPolicy.border.withOpacity(0.7)), boxShadow: ThixPolicy.shadowSoft(opacity: 0.04)),
                  child: Row(children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: imageUrl != null
                          ? CachedNetworkImage(
                              imageUrl: imageUrl,
                              width: 58,
                              height: 58,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(width: 58, height: 58, color: ThixPolicy.surfaceSoft, child: const Icon(Icons.image_outlined, size: 20, color: ThixPolicy.textMuted)),
                              errorWidget: (_, __, ___) => Container(width: 58, height: 58, color: ThixPolicy.surfaceSoft, child: const Icon(Icons.broken_image_outlined, size: 20, color: ThixPolicy.textMuted)),
                            )
                          : Container(width: 58, height: 58, color: ThixPolicy.surfaceSoft, child: const Icon(Icons.shopping_bag_outlined, size: 24, color: ThixPolicy.textMuted)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(title.isEmpty ? chatTr(l10n, 'chat_product_fallback', 'Produit') : title,
                            maxLines: 2, overflow: TextOverflow.ellipsis, style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.semiBold, fontSize: 13, color: ThixPolicy.textMain)),
                        if (priceText.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(children: [
                            Flexible(child: Text(priceText, maxLines: 1, overflow: TextOverflow.ellipsis, style: ThixPolicy.captionStyle.copyWith(fontWeight: ThixPolicy.bold, fontSize: 13, color: ThixPolicy.inkDeep))),
                            if (isConverted) ...[const SizedBox(width: 4), const Icon(Icons.currency_exchange_rounded, size: 10, color: ThixPolicy.textSecondary)],
                          ]),
                        ],
                      ]),
                    ),
                    if (canOpen) const Icon(Icons.chevron_right_rounded, size: 18, color: ThixPolicy.textMuted),
                  ]),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 3, left: 4, right: 4),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(DateFormat('HH:mm').format(time), style: ThixPolicy.microStyle.copyWith(fontSize: 10, color: ThixPolicy.textMuted)),
                if (isOwn) ...[
                  const SizedBox(width: 3),
                  Icon(isRead ? Icons.done_all_rounded : Icons.done_rounded, size: 13, color: isRead ? ThixPolicy.success : ThixPolicy.textMuted),
                ],
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// LECTEUR AUDIO (waveform + vitesse)
// ============================================================================
class ChatWaveformAudioPlayer extends StatefulWidget {
  final String audioUrl;
  final bool isLocal;
  final bool onDark;
  const ChatWaveformAudioPlayer({super.key, required this.audioUrl, this.isLocal = false, this.onDark = true});
  @override
  State<ChatWaveformAudioPlayer> createState() => _ChatWaveformAudioPlayerState();
}

class _ChatWaveformAudioPlayerState extends State<ChatWaveformAudioPlayer> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final List<StreamSubscription<dynamic>> _subs = [];
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  int _speedIdx = 0;
  static const List<double> _speeds = [1.0, 1.5, 2.0];

  @override
  void initState() {
    super.initState();
    if (widget.isLocal && !kIsWeb) {
      _audioPlayer.setSourceDeviceFile(widget.audioUrl);
    } else {
      _audioPlayer.setSourceUrl(widget.audioUrl);
    }
    _subs.add(_audioPlayer.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _isPlaying = s == PlayerState.playing);
    }));
    _subs.add(_audioPlayer.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    }));
    _subs.add(_audioPlayer.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    }));
    _subs.add(_audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) setState(() {
        _position = Duration.zero;
        _isPlaying = false;
      });
    }));
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _audioPlayer.stop();
    _audioPlayer.dispose();
    super.dispose();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final progress = _duration.inMilliseconds > 0 ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0) : 0.0;
    final onDark = widget.onDark;
    final playBg = onDark ? ThixPolicy.gold : ThixPolicy.inkDeep;
    final playFg = onDark ? ThixPolicy.inkDeep : Colors.white;
    final played = onDark ? ThixPolicy.gold : ThixPolicy.inkDeep;
    final idle = onDark ? Colors.white30 : Colors.black26;
    final txt = onDark ? Colors.white : ThixPolicy.textSecondary;
    return Row(children: [
      GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          if (_isPlaying) {
            _audioPlayer.pause();
          } else {
            _audioPlayer.resume();
          }
        },
        child: Container(width: 32, height: 32, decoration: BoxDecoration(color: playBg, shape: BoxShape.circle), child: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: playFg, size: 20)),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: LayoutBuilder(builder: (context, c) {
          return GestureDetector(
            onTapDown: (d) {
              if (_duration.inMilliseconds > 0) {
                _audioPlayer.seek(Duration(milliseconds: (_duration.inMilliseconds * (d.localPosition.dx / c.maxWidth).clamp(0.0, 1.0)).round()));
              }
            },
            child: SizedBox(height: 24, width: c.maxWidth, child: CustomPaint(painter: _WavePainter(progress: progress, played: played, idle: idle))),
          );
        }),
      ),
      const SizedBox(width: 8),
      Text(_fmt(_duration.inSeconds > 0 && !_isPlaying && _position.inSeconds == 0 ? _duration : _position), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: txt)),
      if (!widget.isLocal) ...[
        const SizedBox(width: 6),
        GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _speedIdx = (_speedIdx + 1) % _speeds.length);
            _audioPlayer.setPlaybackRate(_speeds[_speedIdx]);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(color: onDark ? Colors.white12 : Colors.black.withOpacity(0.07), borderRadius: BorderRadius.circular(8)),
            child: Text('${_speeds[_speedIdx] == 1.0 ? '1' : _speeds[_speedIdx]}x', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: txt)),
          ),
        ),
      ],
    ]);
  }
}

class _WavePainter extends CustomPainter {
  final double progress;
  final Color played;
  final Color idle;
  _WavePainter({required this.progress, required this.played, required this.idle});
  static const List<double> _pattern = [0.4, 0.7, 0.5, 0.9, 0.6, 0.4, 0.8, 1.0, 0.5, 0.3, 0.7, 0.8, 0.4, 0.6];
  @override
  void paint(Canvas canvas, Size size) {
    const barW = 3.0;
    const gap = 2.0;
    final count = (size.width / (barW + gap)).floor();
    final paint = Paint()..strokeCap = StrokeCap.round;
    for (var i = 0; i < count; i++) {
      final h = size.height * _pattern[i % _pattern.length];
      final x = i * (barW + gap) + barW / 2;
      paint
        ..color = (i / count) <= progress ? played : idle
        ..strokeWidth = barW;
      canvas.drawLine(Offset(x, (size.height - h) / 2), Offset(x, (size.height + h) / 2), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WavePainter old) => old.progress != progress || old.played != played || old.idle != idle;
}
