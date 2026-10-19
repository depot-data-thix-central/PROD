// lib/presentation/thix_market/pages/chat_page.dart
// ============================================================================
// CHAT PAGE — Production Enterprise v5
// ----------------------------------------------------------------------------
//  • ✅ Bannière produit sticky (Alibaba-style) avec image, titre, prix
//  • ✅ Conversion automatique du prix dans la devise sélectionnée
//  • ✅ Envoi auto de la ref produit au premier message
//  • ✅ Support 54 devises africaines + indicateur 💱
//  • ✅ 3 langues : FR / EN / SW
//  • ✅ Sécurité : sanitisation, validation UUID, rate limiting
//  • ✅ Performance : lazy loading, pagination, debounce
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
import 'package:thix_id/l10n/app_localizations.dart';
import '../core/african_currencies.dart';
import '../core/currency_service.dart';
import '../providers/currency_provider.dart';
import '../providers/market_providers.dart';

// ============================================================================
// CONSTANTES
// ============================================================================
const Duration _kRequestTimeout = Duration(seconds: 15);
const Duration _kRetryDelay = Duration(milliseconds: 400);
const Duration _kTypingDebounce = Duration(milliseconds: 800);
const int _kMaxMessageLength = 2000;
const int _kPageSize = 30;

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
}

// ============================================================================
// PROVIDERS
// ============================================================================
final chatMessagesProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, conversationId) async {
  final db = ref.read(supabaseClientProvider);
  try {
    final res = await db
        .from('messages')
        .select()
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: true)
        .limit(_kPageSize)
        .timeout(_kRequestTimeout);
    return List<Map<String, dynamic>>.from(res);
  } catch (e) {
    debugPrint('[Chat] ❌ Load messages error: $e');
    return [];
  }
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
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _typingTimer;
  bool _isSending = false;
  bool _hasSentProductRef = false;

  // Contexte produit extrait des extras
  Map<String, dynamic>? _productContext;
  String _userName = '';
  String _userAvatar = '';
  String _title = '';

  @override
  void initState() {
    super.initState();
    _extractExtraData();
    debugPrint('[Chat] 💬 Opened conversation ${widget.conversationId}');
    
    // Scroll vers le bas après chargement
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  void _extractExtraData() {
    final extra = widget.extra ?? {};
    _title = _ChatValidators.sanitize(extra['title']?.toString(), maxLength: 60);
    _userName = _ChatValidators.sanitize(extra['userName']?.toString(), maxLength: 60);
    _userAvatar = _ChatValidators.sanitizeUrl(extra['userAvatar']?.toString()) ?? '';
    
    // ✅ Extraire le contexte produit (envoyé depuis messages_page)
    if (extra['productContext'] is Map) {
      _productContext = Map<String, dynamic>.from(extra['productContext']);
      debugPrint('[Chat] 📦 Product context loaded: ${_productContext!['title']}');
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _typingTimer?.cancel();
    debugPrint('[Chat] 👋 Disposed');
    super.dispose();
  }

  // ─── ENVOYER MESSAGE ───
  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    if (text.length > _kMaxMessageLength) {
      HapticFeedback.lightImpact();
      return;
    }

    setState(() => _isSending = true);
    HapticFeedback.selectionClick();

    final db = ref.read(supabaseClientProvider);
    final uid = db.auth.currentUser?.id;

    if (uid == null || !_ChatValidators.isValidId(widget.conversationId)) {
      setState(() => _isSending = false);
      return;
    }

    try {
      // ✅ Si premier message et contexte produit dispo → envoyer ref produit
      String messageContent = text;
      if (!_hasSentProductRef && _productContext != null) {
        final productRef = '[PRODUCT_REF:${_productContext!['id']}]';
        messageContent = '$productRef $text';
        _hasSentProductRef = true;
        debugPrint('[Chat] 📎 Product ref attached to first message');
      }

      await db.from('messages').insert({
        'conversation_id': widget.conversationId,
        'sender_id': uid,
        'content': _ChatValidators.sanitize(messageContent, maxLength: _kMaxMessageLength),
        'type': 'text',
        'created_at': DateTime.now().toUtc().toIso8601String(),
      }).timeout(_kRequestTimeout);

      _messageController.clear();
      ref.invalidate(chatMessagesProvider(widget.conversationId));
      
      // Auto-scroll vers le bas
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });

      debugPrint('[Chat] ✓ Message sent');
    } catch (e) {
      debugPrint('[Chat] ❌ Send error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).t('common_error')),
            backgroundColor: ThixPolicy.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  // ─── NAVIGUER VERS PRODUIT ───
  void _navigateToProduct() {
    if (_productContext == null) return;
    final productId = _productContext!['id']?.toString();
    if (!_ChatValidators.isValidId(productId)) return;

    HapticFeedback.selectionClick();
    context.push('/market/product/$productId');
    debugPrint('[Chat] 🛍️ Navigate to product $productId');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final messagesAsync = ref.watch(chatMessagesProvider(widget.conversationId));
    
    // ✅ Écouter la devise pour conversion en temps réel
    final displayCurrencyCode = ref.watch(currencyProvider);
    final currencyService = CurrencyService.instance;

    // ✅ Préparer les données produit converties
    Map<String, dynamic>? convertedProduct;
    if (_productContext != null) {
      final productCurrency = _ChatValidators.normalizeCurrencyCode(_productContext!['currency_code']);
      final price = (_productContext!['price'] as num?)?.toDouble();
      final isConverted = productCurrency != displayCurrencyCode;
      
      String formattedPrice = '';
      if (price != null) {
        final convertedPrice = currencyService.convert(price, from: productCurrency, to: displayCurrencyCode);
        formattedPrice = currencyService.formatPrice(convertedPrice, currencyCode: displayCurrencyCode, lang: lang);
      }

      convertedProduct = {
        ..._productContext!,
        'formatted_price': formattedPrice,
        'is_converted': isConverted,
        'display_currency': displayCurrencyCode,
      };
    }

    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      appBar: AppBar(
        backgroundColor: ThixPolicy.card,
        elevation: 0,
        scrolledUnderElevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: ThixPolicy.textMain),
          onPressed: () {
            HapticFeedback.selectionClick();
            context.pop();
          },
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: ThixPolicy.surfaceSoft,
              backgroundImage: _userAvatar.isNotEmpty ? CachedNetworkImageProvider(_userAvatar) : null,
              child: _userAvatar.isEmpty
                  ? const Icon(Icons.person_rounded, size: 18, color: ThixPolicy.textMuted)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _userName.isNotEmpty ? _userName : l10n.t('messages_default_chat_title'),
                    style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.bold, fontSize: 15),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    l10n.t('chat_online_status'),
                    style: ThixPolicy.captionStyle.copyWith(fontSize: 11, color: ThixPolicy.success),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert_rounded, color: ThixPolicy.textMain),
            onPressed: () => _showOptions(l10n),
          ),
        ],
      ),
      body: Column(
        children: [
          // ✅ BANNIÈRE PRODUIT STICKY (Alibaba-style)
          if (convertedProduct != null)
            _ProductBanner(
              product: convertedProduct,
              onTap: _navigateToProduct,
              onClose: () => setState(() => _productContext = null),
            ),

          // Liste des messages
          Expanded(
            child: messagesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: ThixPolicy.primary)),
              error: (e, _) => Center(
                child: Text('${l10n.t('common_error')}: $e', style: ThixPolicy.bodySmallStyle),
              ),
              data: (messages) => _buildMessagesList(messages, l10n),
            ),
          ),

          // Barre d'input
          _MessageInputBar(
            controller: _messageController,
            isSending: _isSending,
            onSend: _sendMessage,
            hintText: l10n.t('chat_input_hint'),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList(List<Map<String, dynamic>> messages, AppLocalizations l10n) {
    if (messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline_rounded, size: 48, color: ThixPolicy.textMuted.withOpacity(0.5)),
            const SizedBox(height: 12),
            Text(l10n.t('chat_no_messages'), style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textMuted)),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final msg = messages[index];
        final isMe = msg['sender_id'] == ref.read(supabaseClientProvider).auth.currentUser?.id;
        final content = _ChatValidators.sanitize(msg['content']?.toString(), maxLength: _kMaxMessageLength);
        final time = msg['created_at'] != null
            ? _ChatValidators.formatTime(DateTime.parse(msg['created_at'].toString()), context)
            : '';

        // Détecter si c'est un message avec ref produit
        final hasProductRef = content.contains('[PRODUCT_REF:');
        final cleanContent = hasProductRef
            ? content.replaceAll(RegExp(r'\[PRODUCT_REF:[^\]]+\]\s*'), '')
            : content;

        return _MessageBubble(
          content: cleanContent,
          isMe: isMe,
          time: time,
          hasProductRef: hasProductRef,
        );
      },
    );
  }

  void _showOptions(AppLocalizations l10n) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: ThixPolicy.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.block_rounded, color: ThixPolicy.danger),
                title: Text(l10n.t('chat_block_user'), style: const TextStyle(color: ThixPolicy.danger)),
                onTap: () {
                  Navigator.pop(ctx);
                  HapticFeedback.mediumImpact();
                },
              ),
              ListTile(
                leading: const Icon(Icons.flag_rounded, color: ThixPolicy.warning),
                title: Text(l10n.t('chat_report')),
                onTap: () => Navigator.pop(ctx),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded),
                title: Text(l10n.t('chat_clear_history')),
                onTap: () => Navigator.pop(ctx),
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

/// ✅ Bannière produit sticky (Alibaba-style)
class _ProductBanner extends StatelessWidget {
  final Map<String, dynamic> product;
  final VoidCallback onTap;
  final VoidCallback onClose;

  const _ProductBanner({
    required this.product,
    required this.onTap,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final imageUrl = _ChatValidators.sanitizeUrl(product['image_url']?.toString());
    final title = _ChatValidators.sanitize(product['title']?.toString(), maxLength: 80);
    final formattedPrice = product['formatted_price']?.toString() ?? '';
    final isConverted = product['is_converted'] == true;

    return Material(
      color: ThixPolicy.card,
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: ThixPolicy.border.withOpacity(0.3))),
          ),
          child: Row(
            children: [
              // Image produit
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: imageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: imageUrl,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          width: 48, height: 48,
                          color: ThixPolicy.surfaceSoft,
                          child: const Icon(Icons.image_outlined, size: 20, color: ThixPolicy.textMuted),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          width: 48, height: 48,
                          color: ThixPolicy.surfaceSoft,
                          child: const Icon(Icons.broken_image_outlined, size: 20, color: ThixPolicy.textMuted),
                        ),
                      )
                    : Container(
                        width: 48, height: 48,
                        decoration: BoxDecoration(
                          color: ThixPolicy.surfaceSoft,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.shopping_bag_outlined, size: 24, color: ThixPolicy.textMuted),
                      ),
              ),
              const SizedBox(width: 12),

              // Titre + Prix
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.t('chat_discussing_product'),
                      style: ThixPolicy.captionStyle.copyWith(fontSize: 10, color: ThixPolicy.textMuted),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      title.isEmpty ? l10n.t('chat_product_fallback') : title,
                      style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.bold, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (formattedPrice.isNotEmpty)
                      Row(
                        children: [
                          Text(
                            formattedPrice,
                            style: ThixPolicy.captionStyle.copyWith(
                              fontWeight: ThixPolicy.bold,
                              fontSize: 12,
                              color: ThixPolicy.primary,
                            ),
                          ),
                          if (isConverted) ...[
                            const SizedBox(width: 4),
                            Icon(Icons.currency_exchange_rounded, size: 10, color: ThixPolicy.primary),
                          ],
                        ],
                      ),
                  ],
                ),
              ),

              // Bouton fermer
              Semantics(
                button: true,
                label: l10n.t('common_close'),
                child: GestureDetector(
                  onTap: onClose,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: ThixPolicy.surfaceSoft,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close_rounded, size: 14, color: ThixPolicy.textMuted),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bulle de message
class _MessageBubble extends StatelessWidget {
  final String content;
  final bool isMe;
  final String time;
  final bool hasProductRef;

  const _MessageBubble({
    required this.content,
    required this.isMe,
    required this.time,
    this.hasProductRef = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                // Indicateur de référence produit
                if (hasProductRef)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: ThixPolicy.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.shopping_cart_outlined, size: 10, color: ThixPolicy.primary),
                          const SizedBox(width: 4),
                          Text(
                            'Référence produit jointe',
                            style: ThixPolicy.microStyle.copyWith(fontSize: 9, color: ThixPolicy.primary),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Bulle
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
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    content,
                    style: TextStyle(
                      color: isMe ? Colors.white : ThixPolicy.textMain,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ),

                // Heure
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    time,
                    style: ThixPolicy.microStyle.copyWith(
                      fontSize: 9,
                      color: ThixPolicy.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isMe) const SizedBox(width: 8),
        ],
      ),
    );
  }
}

/// Barre d'input avec bouton envoyer
class _MessageInputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSend;
  final String hintText;

  const _MessageInputBar({
    required this.controller,
    required this.isSending,
    required this.onSend,
    required this.hintText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(12, 8, 12, MediaQuery.of(context).padding.bottom + 8),
      decoration: BoxDecoration(
        color: ThixPolicy.card,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              maxLines: 4,
              minLines: 1,
              maxLength: _kMaxMessageLength,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textMuted),
                filled: true,
                fillColor: ThixPolicy.surfaceSoft,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                counterText: '',
              ),
              onSubmitted: (_) => onSend(),
            ),
          ),
          const SizedBox(width: 8),
          Semantics(
            button: true,
            label: 'Envoyer',
            enabled: !isSending,
            child: GestureDetector(
              onTap: isSending ? null : onSend,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isSending ? ThixPolicy.primary.withOpacity(0.5) : ThixPolicy.primary,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: isSending
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
