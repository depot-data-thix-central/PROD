// lib/presentation/thix_market/pages/chat_page.dart
// ============================================================================
// CHAT PAGE — Production Enterprise v6 (Alibaba-style)
// ----------------------------------------------------------------------------
//  • Barre du haut : boutique, appel, options
//  • Carte "Demander à propos de ce produit" + bouton Send (envoie la carte)
//  • Carte produit cliquable dans les bulles, prix converti en temps réel
//  • Temps réel (stream), indicateur de saisie, accusés de lecture
//  • Séparateurs de date, réponses rapides, en-tête de bienvenue
//  • 3 langues FR / EN / SW (sans dépendre de clés l10n)
// ============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import '../core/african_currencies.dart';
import '../core/chat_service.dart';
import '../core/currency_service.dart';
import '../providers/currency_provider.dart';
import '../providers/market_providers.dart';

// ============================================================================
// CONSTANTES
// ============================================================================
const int _kMaxMessageLength = 2000;
const Duration _kTypingStop = Duration(seconds: 2);

String _tr(BuildContext context, String fr, String en, [String? sw]) {
  final lang = Localizations.localeOf(context).languageCode;
  if (lang == 'sw' && sw != null) return sw;
  return lang == 'fr' ? fr : en;
}

// ============================================================================
// VALIDATEURS
// ============================================================================
class _ChatValidators {
  _ChatValidators._();

  static String sanitize(String? input, {int maxLength = 500}) {
    if (input == null || input.trim().isEmpty) return '';
    final doc = html_parser.parse(input);
    var s = doc.body?.text ?? input;
    s = s
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'javascript:', caseSensitive: false), '')
        .replaceAll(RegExp(r'on\w+\s*=', caseSensitive: false), '')
        // garde \n (0x0A) et \t (0x09) pour les messages multi-lignes
        .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '')
        .trim();
    return s.length > maxLength ? s.substring(0, maxLength) : s;
  }

  static String? sanitizeUrl(String? url) {
    if (url == null || url.trim().isEmpty) return null;
    final t = url.trim();
    if (!t.startsWith('http://') && !t.startsWith('https://')) return null;
    return t.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
  }

  static bool isValidId(String? id) {
    if (id == null || id.isEmpty) return false;
    return RegExp(r'^[0-9a-fA-F-]{8,}$').hasMatch(id);
  }

  static String normalizeCurrencyCode(dynamic c) {
    if (c == null) return 'CDF';
    final v = c.toString().toUpperCase().trim();
    if (AfricanCurrencies.byCode(v) != null) return v;
    final aliases = <String, String>{
      'FC': 'CDF', 'FCFA': 'XOF', r'$': 'USD',
      'DOLLAR': 'USD', 'US': 'USD', 'EURO': 'EUR', '€': 'EUR',
    };
    return aliases[v] ?? 'CDF';
  }

  static String formatTime(DateTime date, BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode;
    return DateFormat('HH:mm', lang).format(date);
  }

  static bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  static String formatDay(DateTime date, BuildContext context) {
    final now = DateTime.now();
    if (sameDay(date, now)) return _tr(context, "Aujourd'hui", 'Today', 'Leo');
    if (sameDay(date, now.subtract(const Duration(days: 1)))) {
      return _tr(context, 'Hier', 'Yesterday', 'Jana');
    }
    final lang = Localizations.localeOf(context).languageCode;
    return DateFormat('dd/MM/yyyy', lang).format(date);
  }
}

String _priceText({
  required double? price,
  required String from,
  required String to,
  required String lang,
}) {
  if (price == null) return '';
  try {
    final service = CurrencyService.instance;
    final converted = service.convert(price, from: from, to: to);
    return service.formatPrice(converted, currencyCode: to, lang: lang);
  } catch (_) {
    return '';
  }
}

// ============================================================================
// MODÈLE LOCAL
// ============================================================================
class _Msg {
  final String id;
  final String senderId;
  final String text;
  final ProductRef? product;
  final String? imageUrl;
  final DateTime createdAt;
  final bool isRead;

  const _Msg({
    required this.id,
    required this.senderId,
    required this.text,
    required this.product,
    required this.imageUrl,
    required this.createdAt,
    required this.isRead,
  });

  factory _Msg.from(Map<String, dynamic> row) {
    final raw = (row['message'] ?? row['content'] ?? '').toString();
    final parsed = ChatService.parse(raw); // avant sanitisation (le token contient des '=')
    final created = DateTime.tryParse(row['created_at']?.toString() ?? '')?.toLocal() ?? DateTime.now();
    return _Msg(
      id: row['id']?.toString() ?? '',
      senderId: row['sender_id']?.toString() ?? '',
      text: _ChatValidators.sanitize(parsed.text, maxLength: _kMaxMessageLength),
      product: parsed.product,
      imageUrl: _ChatValidators.sanitizeUrl(row['image_url']?.toString()),
      createdAt: created,
      isRead: row['is_read'] == true,
    );
  }
}

// ============================================================================
// PROVIDERS
// ============================================================================
final chatMessagesProvider = StreamProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, conversationId) {
  final db = ref.read(supabaseClientProvider);
  return ChatService(db).watchMessages(conversationId);
});

// ============================================================================
// PAGE PRINCIPALE
// ============================================================================
class ChatPage extends ConsumerStatefulWidget {
  final String conversationId;
  final Map<String, dynamic>? extra;

  const ChatPage({super.key, required this.conversationId, this.extra});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  late final ChatService _service;
  RealtimeChannel? _typingChannel;
  Timer? _typingStopTimer;
  Timer? _otherTypingTimer;

  bool _isSending = false;
  bool _isSendingProduct = false;
  bool _iAmTyping = false;
  bool _otherTyping = false;
  bool _markingRead = false;
  bool _productDismissed = false;
  final Set<String> _sentProductIds = {};

  Map<String, dynamic>? _productContext;
  String _userName = '';
  String _userAvatar = '';
  String _shopId = '';

  String? get _me => ref.read(supabaseClientProvider).auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _service = ChatService(ref.read(supabaseClientProvider));
    _extractExtraData();
    debugPrint('[Chat] 💬 Opened conversation ${widget.conversationId}');

    if (_ChatValidators.isValidId(widget.conversationId)) {
      _typingChannel = _service.subscribeTyping(widget.conversationId, (userId, typing) {
        if (!mounted || userId == _me) return;
        setState(() => _otherTyping = typing);
        _otherTypingTimer?.cancel();
        if (typing) {
          _otherTypingTimer = Timer(const Duration(seconds: 4), () {
            if (mounted) setState(() => _otherTyping = false);
          });
        }
      });
      _service.markRead(widget.conversationId);
    }
    _controller.addListener(_onTextChanged);
  }

  void _extractExtraData() {
    final extra = widget.extra ?? {};
    _userName = _ChatValidators.sanitize(extra['userName']?.toString() ?? extra['title']?.toString(), maxLength: 60);
    _userAvatar = _ChatValidators.sanitizeUrl(extra['userAvatar']?.toString()) ?? '';
    final shopId = extra['shopId']?.toString() ?? '';
    _shopId = _ChatValidators.isValidId(shopId) ? shopId : '';

    if (extra['productContext'] is Map) {
      final ctx = Map<String, dynamic>.from(extra['productContext'] as Map);
      if (_ChatValidators.isValidId(ctx['id']?.toString())) {
        _productContext = ctx;
        if (_shopId.isEmpty && _ChatValidators.isValidId(ctx['shop_id']?.toString())) {
          _shopId = ctx['shop_id'].toString();
        }
        debugPrint('[Chat] 📦 Product context: ${ctx['title']}');
      }
    }
  }

  @override
  void dispose() {
    _typingStopTimer?.cancel();
    _otherTypingTimer?.cancel();
    if (_iAmTyping && _typingChannel != null) {
      _service.sendTyping(_typingChannel!, false);
    }
    _service.disposeChannel(_typingChannel);
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    debugPrint('[Chat] 👋 Disposed');
    super.dispose();
  }

  // ─── SAISIE ───
  void _onTextChanged() {
    final channel = _typingChannel;
    if (channel == null) return;
    if (_controller.text.trim().isEmpty) {
      _stopTyping();
      return;
    }
    if (!_iAmTyping) {
      _iAmTyping = true;
      _service.sendTyping(channel, true);
    }
    _typingStopTimer?.cancel();
    _typingStopTimer = Timer(_kTypingStop, _stopTyping);
  }

  void _stopTyping() {
    _typingStopTimer?.cancel();
    if (_iAmTyping && _typingChannel != null) {
      _iAmTyping = false;
      _service.sendTyping(_typingChannel!, false);
    }
  }

  // ─── LECTURE ───
  void _maybeMarkRead(List<Map<String, dynamic>> rows) {
    final me = _me;
    if (me == null || _markingRead) return;
    final hasUnread = rows.any((r) => r['sender_id']?.toString() != me && r['is_read'] != true);
    if (!hasUnread) return;
    _markingRead = true;
    _service.markRead(widget.conversationId).whenComplete(() => _markingRead = false);
  }

  // ─── ENVOI TEXTE ───
  Future<void> _sendMessage() async {
    final text = _ChatValidators.sanitize(_controller.text, maxLength: _kMaxMessageLength);
    if (text.isEmpty || _isSending) return;
    if (!_ChatValidators.isValidId(widget.conversationId)) return;

    setState(() => _isSending = true);
    HapticFeedback.selectionClick();

    try {
      await _service.sendText(widget.conversationId, text);
      _controller.clear();
      _stopTyping();
      debugPrint('[Chat] ✓ Message sent');
    } on ChatException catch (e) {
      debugPrint('[Chat] ❌ Send error: $e');
      _showError(_tr(context, "Message non envoyé. Réessayez.", 'Message not sent. Try again.', 'Ujumbe haujatumwa. Jaribu tena.'));
    } catch (e) {
      debugPrint('[Chat] ❌ Send error: $e');
      _showError(_tr(context, "Message non envoyé. Réessayez.", 'Message not sent. Try again.', 'Ujumbe haujatumwa. Jaribu tena.'));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  // ─── ENVOI CARTE PRODUIT ───
  Future<void> _sendProductCard() async {
    final ctx = _productContext;
    if (ctx == null || _isSendingProduct) return;
    if (!_ChatValidators.isValidId(widget.conversationId)) return;

    setState(() => _isSendingProduct = true);
    HapticFeedback.mediumImpact();

    try {
      final ref0 = ProductRef.fromContext({
        ...ctx,
        'currency_code': _ChatValidators.normalizeCurrencyCode(ctx['currency_code']),
        'shop_id': ctx['shop_id'] ?? (_shopId.isEmpty ? null : _shopId),
      });
      await _service.sendProduct(widget.conversationId, ref0);
      if (mounted) setState(() => _sentProductIds.add(ref0.id));
      debugPrint('[Chat] 📎 Product card sent');
    } catch (e) {
      debugPrint('[Chat] ❌ Product send error: $e');
      _showError(_tr(context, "Produit non envoyé. Réessayez.", 'Product not sent. Try again.', 'Bidhaa haijatumwa. Jaribu tena.'));
    } finally {
      if (mounted) setState(() => _isSendingProduct = false);
    }
  }

  // ─── NAVIGATION ───
  void _openProduct(String? productId) {
    if (!_ChatValidators.isValidId(productId)) return;
    HapticFeedback.selectionClick();
    context.push('/market/product/$productId');
  }

  void _openShop() {
    if (_shopId.isEmpty) {
      _showError(_tr(context, 'Boutique indisponible', 'Store unavailable', 'Duka halipatikani'));
      return;
    }
    HapticFeedback.selectionClick();
    context.push('/market/shop/$_shopId');
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: ThixPolicy.danger,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showInfo(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: ThixPolicy.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _fillQuickReply(String text) {
    HapticFeedback.selectionClick();
    _controller.text = text;
    _controller.selection = TextSelection.fromPosition(TextPosition(offset: text.length));
    _focusNode.requestFocus();
  }

  // ─── BUILD ───
  @override
  Widget build(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode;
    final messagesAsync = ref.watch(chatMessagesProvider(widget.conversationId));
    final displayCurrencyCode = ref.watch(currencyProvider);

    ref.listen<AsyncValue<List<Map<String, dynamic>>>>(
      chatMessagesProvider(widget.conversationId),
      (prev, next) => next.whenData(_maybeMarkRead),
    );

    final name = _userName.isNotEmpty
        ? _userName
        : _tr(context, 'Vendeur', 'Seller', 'Muuzaji');

    // Bannière "Demander à propos de ce produit"
    Widget? inquiryBar;
    final ctx = _productContext;
    if (ctx != null && !_productDismissed && !_sentProductIds.contains(ctx['id']?.toString())) {
      final fromCode = _ChatValidators.normalizeCurrencyCode(ctx['currency_code']);
      final price = (ctx['price'] as num?)?.toDouble();
      inquiryBar = _InquiryBar(
        imageUrl: _ChatValidators.sanitizeUrl(ctx['image_url']?.toString()),
        title: _ChatValidators.sanitize(ctx['title']?.toString(), maxLength: 80),
        priceText: _priceText(price: price, from: fromCode, to: displayCurrencyCode, lang: lang),
        isConverted: fromCode != displayCurrencyCode,
        isSending: _isSendingProduct,
        onSend: _sendProductCard,
        onTap: () => _openProduct(ctx['id']?.toString()),
        onClose: () => setState(() => _productDismissed = true),
      );
    }

    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      appBar: AppBar(
        backgroundColor: ThixPolicy.card,
        elevation: 0,
        scrolledUnderElevation: 1,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: ThixPolicy.textMain),
          onPressed: () {
            HapticFeedback.selectionClick();
            if (context.canPop()) context.pop();
          },
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: ThixPolicy.surfaceSoft,
              backgroundImage: _userAvatar.isNotEmpty ? CachedNetworkImageProvider(_userAvatar) : null,
              child: _userAvatar.isEmpty
                  ? const Icon(Icons.storefront_rounded, size: 18, color: ThixPolicy.textMuted)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.bold, fontSize: 15, color: ThixPolicy.textMain),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _otherTyping
                        ? _tr(context, 'écrit…', 'typing…', 'anaandika…')
                        : _tr(context, 'Vendeur', 'Seller', 'Muuzaji'),
                    style: ThixPolicy.captionStyle.copyWith(
                      fontSize: 11,
                      color: _otherTyping ? ThixPolicy.primary : ThixPolicy.textMuted,
                      fontStyle: _otherTyping ? FontStyle.italic : FontStyle.normal,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: _tr(context, 'Boutique', 'Store', 'Duka'),
            icon: const Icon(Icons.storefront_outlined, color: ThixPolicy.textMain),
            onPressed: _openShop,
          ),
          IconButton(
            tooltip: _tr(context, 'Appel', 'Call', 'Simu'),
            icon: const Icon(Icons.call_outlined, color: ThixPolicy.textMain),
            onPressed: _showCallSheet,
          ),
          IconButton(
            tooltip: _tr(context, 'Options', 'Options', 'Chaguo'),
            icon: const Icon(Icons.more_vert_rounded, color: ThixPolicy.textMain),
            onPressed: _showOptions,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: ThixPolicy.primary)),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 40, color: ThixPolicy.danger),
                      const SizedBox(height: 12),
                      Text(
                        _tr(context, 'Impossible de charger les messages', 'Unable to load messages', 'Imeshindwa kupakia ujumbe'),
                        style: ThixPolicy.bodySmallStyle,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: () => ref.invalidate(chatMessagesProvider(widget.conversationId)),
                        icon: const Icon(Icons.refresh_rounded),
                        label: Text(_tr(context, 'Réessayer', 'Retry', 'Jaribu tena')),
                      ),
                    ],
                  ),
                ),
              ),
              data: (rows) => _buildMessagesList(rows, name),
            ),
          ),
          if (inquiryBar != null) inquiryBar,
          _QuickActions(
            hasProduct: _productContext != null,
            hasShop: _shopId.isNotEmpty,
            onShop: _openShop,
            onProduct: () => _openProduct(_productContext?['id']?.toString()),
            onReply: _fillQuickReply,
          ),
          _MessageInputBar(
            controller: _controller,
            focusNode: _focusNode,
            isSending: _isSending,
            onSend: _sendMessage,
            hintText: _tr(context, 'Écrire un message…', 'Enter your message…', 'Andika ujumbe…'),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList(List<Map<String, dynamic>> rows, String name) {
    final me = _me;
    final msgs = rows.map(_Msg.from).toList(); // ordre décroissant (récent en premier)

    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: msgs.length + 1,
      itemBuilder: (context, index) {
        if (index == msgs.length) {
          return _WelcomeHeader(name: name, avatarUrl: _userAvatar);
        }
        final m = msgs[index];
        final older = index + 1 < msgs.length ? msgs[index + 1] : null;
        final showDay = older == null || !_ChatValidators.sameDay(older.createdAt, m.createdAt);
        final isMe = me != null && m.senderId == me;
        final time = _ChatValidators.formatTime(m.createdAt, context);

        return Column(
          key: ValueKey(m.id),
          children: [
            if (showDay) _DaySeparator(label: _ChatValidators.formatDay(m.createdAt, context)),
            if (m.product != null)
              _ProductCardBubble(
                product: m.product!,
                isMe: isMe,
                time: time,
                isRead: m.isRead,
                onTap: () => _openProduct(m.product!.id),
              ),
            if (m.text.isNotEmpty || m.imageUrl != null)
              _MessageBubble(
                content: m.text,
                imageUrl: m.imageUrl,
                isMe: isMe,
                time: time,
                isRead: m.isRead,
              ),
          ],
        );
      },
    );
  }

  // ─── SHEETS ───
  void _showCallSheet() {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: ThixPolicy.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: ThixPolicy.border, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.call_rounded, color: ThixPolicy.primary),
                title: Text(_tr(context, 'Appel vocal', 'Voice call', 'Simu ya sauti')),
                onTap: () {
                  Navigator.pop(ctx);
                  _showInfo(_tr(context, 'Bientôt disponible', 'Coming soon', 'Inakuja hivi karibuni'));
                },
              ),
              ListTile(
                leading: const Icon(Icons.videocam_rounded, color: ThixPolicy.primary),
                title: Text(_tr(context, 'Appel vidéo', 'Video call', 'Simu ya video')),
                onTap: () {
                  Navigator.pop(ctx);
                  _showInfo(_tr(context, 'Bientôt disponible', 'Coming soon', 'Inakuja hivi karibuni'));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showOptions() {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: ThixPolicy.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: ThixPolicy.border, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.storefront_rounded, color: ThixPolicy.domainMarket),
                title: Text(_tr(context, 'Voir la boutique', 'Visit store', 'Tembelea duka')),
                onTap: () {
                  Navigator.pop(ctx);
                  _openShop();
                },
              ),
              if (_productContext != null)
                ListTile(
                  leading: const Icon(Icons.shopping_bag_outlined, color: ThixPolicy.primary),
                  title: Text(_tr(context, 'Voir le produit', 'View product', 'Ona bidhaa')),
                  onTap: () {
                    Navigator.pop(ctx);
                    _openProduct(_productContext?['id']?.toString());
                  },
                ),
              ListTile(
                leading: const Icon(Icons.refresh_rounded),
                title: Text(_tr(context, 'Actualiser', 'Refresh', 'Onyesha upya')),
                onTap: () {
                  Navigator.pop(ctx);
                  ref.invalidate(chatMessagesProvider(widget.conversationId));
                },
              ),
              ListTile(
                leading: const Icon(Icons.flag_rounded, color: ThixPolicy.warning),
                title: Text(_tr(context, 'Signaler', 'Report', 'Ripoti')),
                onTap: () {
                  Navigator.pop(ctx);
                  _showInfo(_tr(context, 'Bientôt disponible', 'Coming soon', 'Inakuja hivi karibuni'));
                },
              ),
              ListTile(
                leading: const Icon(Icons.block_rounded, color: ThixPolicy.danger),
                title: Text(_tr(context, "Bloquer l'utilisateur", 'Block user', 'Zuia mtumiaji'),
                    style: const TextStyle(color: ThixPolicy.danger)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showInfo(_tr(context, 'Bientôt disponible', 'Coming soon', 'Inakuja hivi karibuni'));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// COMPOSANTS
// ============================================================================

/// En-tête de bienvenue (haut de la conversation)
class _WelcomeHeader extends StatelessWidget {
  final String name;
  final String avatarUrl;
  const _WelcomeHeader({required this.name, required this.avatarUrl});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 16),
      child: Column(
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: ThixPolicy.card,
            backgroundImage: avatarUrl.isNotEmpty ? CachedNetworkImageProvider(avatarUrl) : null,
            child: avatarUrl.isEmpty ? const Icon(Icons.storefront_rounded, size: 34, color: ThixPolicy.textMuted) : null,
          ),
          const SizedBox(height: 10),
          Text(
            name,
            style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.bold, fontSize: 15, color: ThixPolicy.textMain),
          ),
          const SizedBox(height: 4),
          Text(
            _tr(context, 'Bienvenue !', 'Welcome!', 'Karibu!'),
            style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.textMain),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: ThixPolicy.card, borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                const Icon(Icons.verified_user_outlined, size: 22, color: ThixPolicy.success),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _tr(
                      context,
                      'Gardez vos discussions et transactions sur THIX pour bénéficier de la protection des commandes.',
                      'Keep chats and transactions on THIX to enjoy order protection.',
                      'Endelea na mazungumzo na miamala kwenye THIX ili kupata ulinzi wa oda.',
                    ),
                    style: ThixPolicy.captionStyle.copyWith(fontSize: 12, color: ThixPolicy.textSecondary, height: 1.35),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DaySeparator extends StatelessWidget {
  final String label;
  const _DaySeparator({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: ThixPolicy.textMuted.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(label, style: ThixPolicy.microStyle.copyWith(fontSize: 10, color: ThixPolicy.textSecondary)),
        ),
      ),
    );
  }
}

/// Carte "Demander à propos de ce produit" + Send (style Alibaba)
class _InquiryBar extends StatelessWidget {
  final String? imageUrl;
  final String title;
  final String priceText;
  final bool isConverted;
  final bool isSending;
  final VoidCallback onSend;
  final VoidCallback onTap;
  final VoidCallback onClose;

  const _InquiryBar({
    required this.imageUrl,
    required this.title,
    required this.priceText,
    required this.isConverted,
    required this.isSending,
    required this.onSend,
    required this.onTap,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ThixPolicy.card,
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _tr(context, 'Demander à propos de ce produit :', 'Inquire about this product:', 'Uliza kuhusu bidhaa hii:'),
                    style: ThixPolicy.captionStyle.copyWith(fontSize: 12, color: ThixPolicy.textMuted),
                  ),
                ),
                Semantics(
                  button: true,
                  label: _tr(context, 'Fermer', 'Close', 'Funga'),
                  child: InkWell(
                    onTap: onClose,
                    borderRadius: BorderRadius.circular(20),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.close_rounded, size: 20, color: ThixPolicy.textSecondary),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: onTap,
                    borderRadius: BorderRadius.circular(8),
                    child: Row(
                      children: [
                        _ProductThumb(imageUrl: imageUrl, size: 56),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (priceText.isNotEmpty)
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        priceText,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: ThixPolicy.labelStyle.copyWith(
                                          fontWeight: ThixPolicy.bold,
                                          fontSize: 16,
                                          color: ThixPolicy.textMain,
                                        ),
                                      ),
                                    ),
                                    if (isConverted) ...[
                                      const SizedBox(width: 4),
                                      const Icon(Icons.currency_exchange_rounded, size: 11, color: ThixPolicy.primary),
                                    ],
                                  ],
                                ),
                              Text(
                                title.isEmpty ? _tr(context, 'Produit', 'Product', 'Bidhaa') : title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: ThixPolicy.captionStyle.copyWith(fontSize: 13, color: ThixPolicy.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Semantics(
                  button: true,
                  label: 'Send',
                  child: ElevatedButton(
                    onPressed: isSending ? null : onSend,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ThixPolicy.domainMarket,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: ThixPolicy.domainMarket.withOpacity(0.5),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                    child: isSending
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(
                            _tr(context, 'Envoyer', 'Send', 'Tuma'),
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                          ),
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

class _ProductThumb extends StatelessWidget {
  final String? imageUrl;
  final double size;
  const _ProductThumb({required this.imageUrl, required this.size});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: imageUrl != null
          ? CachedNetworkImage(
              imageUrl: imageUrl!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                width: size, height: size, color: ThixPolicy.surfaceSoft,
                child: const Icon(Icons.image_outlined, size: 20, color: ThixPolicy.textMuted),
              ),
              errorWidget: (_, __, ___) => Container(
                width: size, height: size, color: ThixPolicy.surfaceSoft,
                child: const Icon(Icons.broken_image_outlined, size: 20, color: ThixPolicy.textMuted),
              ),
            )
          : Container(
              width: size, height: size, color: ThixPolicy.surfaceSoft,
              child: const Icon(Icons.shopping_bag_outlined, size: 24, color: ThixPolicy.textMuted),
            ),
    );
  }
}

/// Raccourcis : boutique, produit, réponses rapides
class _QuickActions extends StatelessWidget {
  final bool hasProduct;
  final bool hasShop;
  final VoidCallback onShop;
  final VoidCallback onProduct;
  final void Function(String) onReply;

  const _QuickActions({
    required this.hasProduct,
    required this.hasShop,
    required this.onShop,
    required this.onProduct,
    required this.onReply,
  });

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      if (hasShop)
        _chip(context, Icons.storefront_outlined, _tr(context, 'Boutique', 'Store', 'Duka'), onShop),
      if (hasProduct)
        _chip(context, Icons.shopping_bag_outlined, _tr(context, 'Produit', 'Product', 'Bidhaa'), onProduct),
      _chip(
        context, null,
        _tr(context, 'Disponible ?', 'Available?', 'Inapatikana?'),
        () => onReply(_tr(context, 'Ce produit est-il disponible ?', 'Is this product available?', 'Je, bidhaa hii inapatikana?')),
      ),
      _chip(
        context, null,
        _tr(context, 'Meilleur prix ?', 'Best price?', 'Bei bora?'),
        () => onReply(_tr(context, 'Quel est votre meilleur prix ?', 'What is your best price?', 'Bei yako bora ni ipi?')),
      ),
      _chip(
        context, null,
        _tr(context, 'Livraison ?', 'Delivery?', 'Uwasilishaji?'),
        () => onReply(_tr(context, 'Quels sont les délais de livraison ?', 'What are the delivery times?', 'Uwasilishaji unachukua muda gani?')),
      ),
    ];

    return Container(
      color: ThixPolicy.card,
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => chips[i],
      ),
    );
  }

  Widget _chip(BuildContext context, IconData? icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: ThixPolicy.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: ThixPolicy.textMain),
              const SizedBox(width: 5),
            ],
            Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: ThixPolicy.textMain)),
          ],
        ),
      ),
    );
  }
}

/// Carte produit dans la conversation (cliquable, prix converti)
class _ProductCardBubble extends ConsumerWidget {
  final ProductRef product;
  final bool isMe;
  final String time;
  final bool isRead;
  final VoidCallback onTap;

  const _ProductCardBubble({
    required this.product,
    required this.isMe,
    required this.time,
    required this.isRead,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final displayCode = ref.watch(currencyProvider);
    final lang = Localizations.localeOf(context).languageCode;
    final from = _ChatValidators.normalizeCurrencyCode(product.currencyCode);
    final priceText = _priceText(price: product.price, from: from, to: displayCode, lang: lang);
    final title = _ChatValidators.sanitize(product.title, maxLength: 80);
    final imageUrl = _ChatValidators.sanitizeUrl(product.imageUrl);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: MediaQuery.of(context).size.width * 0.72,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: ThixPolicy.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: ThixPolicy.border.withOpacity(0.7)),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 2))],
                ),
                child: Row(
                  children: [
                    _ProductThumb(imageUrl: imageUrl, size: 56),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title.isEmpty ? _tr(context, 'Produit', 'Product', 'Bidhaa') : title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.semiBold, fontSize: 13, color: ThixPolicy.textMain),
                          ),
                          if (priceText.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    priceText,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: ThixPolicy.captionStyle.copyWith(fontWeight: ThixPolicy.bold, fontSize: 13, color: ThixPolicy.primary),
                                  ),
                                ),
                                if (from != displayCode) ...[
                                  const SizedBox(width: 4),
                                  const Icon(Icons.currency_exchange_rounded, size: 10, color: ThixPolicy.primary),
                                ],
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, size: 18, color: ThixPolicy.textMuted),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: _TimeAndTicks(time: time, isMe: isMe, isRead: isRead),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeAndTicks extends StatelessWidget {
  final String time;
  final bool isMe;
  final bool isRead;
  const _TimeAndTicks({required this.time, required this.isMe, required this.isRead});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(time, style: ThixPolicy.microStyle.copyWith(fontSize: 9, color: ThixPolicy.textMuted)),
        if (isMe) ...[
          const SizedBox(width: 3),
          Icon(
            isRead ? Icons.done_all_rounded : Icons.done_rounded,
            size: 12,
            color: isRead ? ThixPolicy.primary : ThixPolicy.textMuted,
          ),
        ],
      ],
    );
  }
}

/// Bulle de message
class _MessageBubble extends StatelessWidget {
  final String content;
  final String? imageUrl;
  final bool isMe;
  final String time;
  final bool isRead;

  const _MessageBubble({
    required this.content,
    required this.imageUrl,
    required this.isMe,
    required this.time,
    required this.isRead,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isMe ? ThixPolicy.primary : ThixPolicy.card,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isMe ? 16 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 16),
                    ),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 2))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (imageUrl != null)
                        Padding(
                          padding: EdgeInsets.only(bottom: content.isNotEmpty ? 8 : 0),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: CachedNetworkImage(
                              imageUrl: imageUrl!,
                              width: 200,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => const Icon(Icons.broken_image_outlined, color: ThixPolicy.textMuted),
                            ),
                          ),
                        ),
                      if (content.isNotEmpty)
                        Text(
                          content,
                          style: TextStyle(
                            color: isMe ? Colors.white : ThixPolicy.textMain,
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: _TimeAndTicks(time: time, isMe: isMe, isRead: isRead),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Barre d'input
class _MessageInputBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isSending;
  final VoidCallback onSend;
  final String hintText;

  const _MessageInputBar({
    required this.controller,
    required this.focusNode,
    required this.isSending,
    required this.onSend,
    required this.hintText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ThixPolicy.card,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, -2))],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  maxLines: 4,
                  minLines: 1,
                  maxLength: _kMaxMessageLength,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: hintText,
                    hintStyle: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textMuted),
                    filled: true,
                    fillColor: ThixPolicy.surfaceSoft,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    counterText: '',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (context, value, _) {
                  final canSend = value.text.trim().isNotEmpty && !isSending;
                  return Semantics(
                    button: true,
                    label: 'Send',
                    enabled: canSend,
                    child: GestureDetector(
                      onTap: canSend ? onSend : null,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: canSend || isSending ? ThixPolicy.primary : ThixPolicy.primary.withOpacity(0.4),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: isSending
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
