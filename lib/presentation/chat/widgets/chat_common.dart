// lib/presentation/chat/widgets/chat_common.dart
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:permission_handler/permission_handler.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/models/chat/chat_message.dart';
import 'package:thix_id/presentation/thix_market/core/chat_service.dart' as market_chat;

const int kChatMaxMessageLength = 5000;
const int kChatMaxFileSizeBytes = 25 * 1024 * 1024;
const int kChatMaxStickerBytes = 512 * 1024;
const int kChatMaxAudioSeconds = 300;

/// Moi : gris propre. Autre : blanc.
const Color kOwnBubbleColor = Color(0xFFE6E7EA);
const Color kOtherBubbleColor = Colors.white;

String chatTr(AppLocalizations l10n, String key, String fallback) {
  final s = l10n.t(key);
  return s == key ? fallback : s;
}

void chatLog(String message) {
  if (kDebugMode) debugPrint(message);
}

// ============================================================================
// SNACKBARS
// ============================================================================
enum ChatSnackKind { success, error, warning, info }

void chatSnack(BuildContext context, String message, ChatSnackKind kind) {
  if (!context.mounted) return;
  late Color bg;
  IconData? icon;
  switch (kind) {
    case ChatSnackKind.success:
      bg = ThixPolicy.success;
      icon = Icons.check_circle_rounded;
      break;
    case ChatSnackKind.error:
      bg = ThixPolicy.danger;
      icon = Icons.error_outline_rounded;
      break;
    case ChatSnackKind.warning:
      bg = ThixPolicy.warning;
      icon = Icons.warning_rounded;
      break;
    case ChatSnackKind.info:
      bg = ThixPolicy.inkDeep;
      icon = null;
      break;
  }
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Row(children: [
        if (icon != null) ...[Icon(icon, color: Colors.white, size: 18), const SizedBox(width: 8)],
        Expanded(child: Text(message)),
      ]),
      backgroundColor: bg,
      behavior: SnackBarBehavior.floating,
      duration: Duration(milliseconds: kind == ChatSnackKind.error ? 3000 : 1600),
    ));
}

// ============================================================================
// PERMISSIONS (avec explication)
// ============================================================================
Future<bool> chatCheckPermission(BuildContext context, Permission permission, String explanation) async {
  if (kIsWeb) return true;
  final status = await permission.status;
  if (status.isGranted) return true;
  if (!context.mounted) return false;
  final l10n = AppLocalizations.of(context);
  final agreed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      backgroundColor: ThixPolicy.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: ThixPolicy.border)),
      title: Row(children: [
        const Icon(Icons.privacy_tip_outlined, color: ThixPolicy.textMain, size: 28),
        const SizedBox(width: 10),
        Expanded(
          child: Text(chatTr(l10n, 'chat_auth_required', 'Autorisation requise'),
              style: ThixPolicy.h3Style.copyWith(color: ThixPolicy.textMain, fontWeight: ThixPolicy.bold)),
        ),
      ]),
      content: Text(explanation, style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textSecondary, fontSize: 16, height: 1.4)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(chatTr(l10n, 'common_cancel', 'Annuler'))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: ThixPolicy.inkDeep,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(chatTr(l10n, 'chat_understood', 'J’ai compris'), style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    ),
  );
  if (agreed != true) return false;
  final res = await permission.request();
  return res.isGranted;
}

// ============================================================================
// VALIDATEURS
// ============================================================================
class ChatValidators {
  ChatValidators._();

  static final RegExp _ctrlKeepNl = RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]');
  static final RegExp _ctrlAll = RegExp(r'[\x00-\x1F\x7F]');
  static final RegExp _bidi = RegExp(r'[\u200B\u200E\u200F\u202A-\u202E\u2066-\u2069\uFEFF]');
  static final RegExp _tags = RegExp(r'<[a-zA-Z/!?][^>]*>');
  static final RegExp _jsScheme = RegExp(r'(javascript|vbscript)\s*:', caseSensitive: false);

  static String sanitize(String? input, {int maxLength = kChatMaxMessageLength}) {
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
    if (msg.contains('too large') || msg.contains('size')) return 'Fichier trop volumineux.';
    if (msg.contains('maximum') || msg.contains('atteint')) return 'Limite atteinte.';
    if (msg.contains('accès refusé')) return 'Accès refusé à cette conversation.';
    return 'Une erreur est survenue. Réessayez.';
  }

  static bool isValidFileSize(int bytes) => bytes > 0 && bytes <= kChatMaxFileSizeBytes;

  static const Set<String> _blockedExt = {
    'exe', 'bat', 'cmd', 'com', 'scr', 'msi', 'sh', 'ps1', 'vbs', 'js', 'jar', 'apk', 'dll', 'lnk',
  };

  static bool isAllowedExtension(String? ext) => !_blockedExt.contains((ext ?? '').toLowerCase());

  static const Set<String> _img = {'jpg', 'jpeg', 'png', 'gif', 'webp'};
  static const Set<String> _vid = {'mp4', 'mov', 'avi', 'mkv', 'webm', '3gp'};
  static const Set<String> _aud = {'mp3', 'wav', 'm4a', 'ogg', 'opus', 'aac'};

  static bool isImageExt(String? ext) => _img.contains((ext ?? '').toLowerCase());

  static String getMediaType(String ext) {
    final e = ext.toLowerCase();
    if (_img.contains(e)) return 'image';
    if (_vid.contains(e)) return 'video';
    if (_aud.contains(e)) return 'audio';
    return 'file';
  }

  static String extOfName(String? name) {
    if (name == null || !name.contains('.')) return '';
    return name.split('.').last.toLowerCase();
  }

  static IconData iconForExtension(String? ext) {
    final e = (ext ?? '').toLowerCase();
    if (_vid.contains(e)) return Icons.videocam_rounded;
    if (_aud.contains(e)) return Icons.audiotrack_rounded;
    if (e == 'pdf') return Icons.picture_as_pdf_rounded;
    if (['doc', 'docx', 'odt', 'rtf'].contains(e)) return Icons.description_rounded;
    if (['xls', 'xlsx', 'csv', 'ods'].contains(e)) return Icons.table_chart_rounded;
    if (['ppt', 'pptx', 'odp'].contains(e)) return Icons.slideshow_rounded;
    if (['zip', 'rar', '7z', 'tar', 'gz'].contains(e)) return Icons.folder_zip_rounded;
    if (['txt', 'md', 'json', 'xml', 'html'].contains(e)) return Icons.article_rounded;
    return Icons.insert_drive_file_rounded;
  }

  static String formatSize(int? bytes) {
    final b = bytes ?? 0;
    if (b <= 0) return '';
    if (b < 1024) return '$b o';
    if (b < 1024 * 1024) return '${(b / 1024).round()} Ko';
    return '${(b / (1024 * 1024)).toStringAsFixed(1)} Mo';
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

  static String extFromBytes(Uint8List bytes, String fallback) {
    if (bytes.length > 3 && bytes[0] == 0xFF && bytes[1] == 0xD8) return 'jpg';
    if (bytes.length > 8 && bytes[0] == 0x89 && bytes[1] == 0x50) return 'png';
    return fallback;
  }
}

// ============================================================================
// RÉFÉRENCE PRODUIT (THIX Market) — avec CACHE (évite de re-parser à chaque build)
// ============================================================================
class ParsedRef {
  final market_chat.ProductRef? product;
  final String text;
  const ParsedRef(this.product, this.text);
}

final Map<String, ParsedRef> _refCache = <String, ParsedRef>{};

ParsedRef chatParseRef(ChatMessage m) {
  final c = m.content;
  if (c.isEmpty || !c.contains('PRODUCT_REF')) return ParsedRef(null, c);
  final key = '${m.id}:${c.hashCode}';
  final hit = _refCache[key];
  if (hit != null) return hit;
  if (_refCache.length > 400) _refCache.clear();
  final parsed = market_chat.ChatService.parse(c);
  final r = ParsedRef(parsed.product, parsed.text ?? '');
  _refCache[key] = r;
  return r;
}

bool isProductRefMessage(ChatMessage m) => chatParseRef(m).product != null;

// ============================================================================
// ✅ MESSAGES CHIFFRÉS (ENCv1:) — aperçus propres partout
// ============================================================================
bool isEncryptedMessage(ChatMessage m) => m.content.trimLeft().startsWith('ENCv1:');

String chatPreviewOf(ChatMessage m) {
  if (isEncryptedMessage(m)) return '🔒 Message protégé';
  final parsed = chatParseRef(m);
  final product = parsed.product;
  if (product == null) return m.previewText;
  final title = ChatValidators.sanitize(product.title, maxLength: 60);
  final rest = ChatValidators.sanitize(parsed.text, maxLength: 80);
  final head = title.isEmpty ? '📦 Produit' : '📦 $title';
  return rest.isEmpty ? head : '$head — $rest';
}

String chatPlainTextOf(ChatMessage m) {
  if (isEncryptedMessage(m)) return '';
  final parsed = chatParseRef(m);
  if (parsed.product == null) return m.content;
  return ChatValidators.sanitize(parsed.text, maxLength: kChatMaxMessageLength);
}

String chatSearchableText(ChatMessage m) {
  if (isEncryptedMessage(m)) return '';
  final parsed = chatParseRef(m);
  final product = parsed.product;
  if (product == null) return m.content;
  return '${product.title} ${parsed.text}';
}

bool chatSameDay(DateTime a, DateTime b) {
  final x = a.toLocal();
  final y = b.toLocal();
  return x.year == y.year && x.month == y.month && x.day == y.day;
}
