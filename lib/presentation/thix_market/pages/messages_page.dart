// lib/presentation/thix_market/pages/messages_page.dart
// ============================================================================
// MESSAGES PAGE — Production Enterprise v5 (FIXED) + EXCEPTION THIX MARKET
// ============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:provider/provider.dart'; 
import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import '../core/african_currencies.dart';
import '../core/currency_service.dart';
import '../providers/currency_provider.dart';
import '../providers/message_provider.dart';

// ============================================================================
// CONSTANTES
// ============================================================================
const Duration _kRequestTimeout = Duration(seconds: 15);
const Duration _kRetryDelay = Duration(milliseconds: 400);

// ============================================================================
// VALIDATEURS
// ============================================================================
class _MessagesValidators {
  _MessagesValidators._();

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

  static String formatDate(String? dateStr, BuildContext context) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final lang = Localizations.localeOf(context).languageCode;
      if (date.day == now.day && date.month == now.month && date.year == now.year) {
        return DateFormat('HH:mm', lang).format(date);
      } else {
        return DateFormat('dd/MM', lang).format(date);
      }
    } catch (_) {
      return sanitize(dateStr, maxLength: 20);
    }
  }

  static String formatFullDate(String? dateStr, BuildContext context) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final lang = Localizations.localeOf(context).languageCode;
      return DateFormat('dd/MM/yyyy', lang).format(DateTime.parse(dateStr));
    } catch (_) {
      return sanitize(dateStr, maxLength: 20);
    }
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

  // ✅ FIX #3 : Méthode PUBLIQUE (pas privée) pour être accessible depuis _ConversationTile
  static Map<String, dynamic>? extractProductFromMetadata(dynamic metadata) {
    if (metadata == null) return null;

    if (metadata is String) {
      final params = Uri.splitQueryString(metadata);
      if (params != null && params.containsKey('product_id')) {
        return {
          'id': params['product_id'],
          'title': params['title']?.replaceAll('%20', ' '),
          'price': double.tryParse(params['price'] ?? ''),
          'currency': normalizeCurrencyCode(params['currency']),
          'image_url': params['image_url'],
        };
      }
    } else if (metadata is Map) {
      final id = metadata['product_id']?.toString();
      if (id != null && isValidId(id)) {
        return {
          'id': id,
          'title': sanitize(metadata['title']?.toString()),
          'price': double.tryParse(metadata['price']?.toString() ?? ''),
          'currency': normalizeCurrencyCode(metadata['currency']),
          'image_url': sanitizeUrl(metadata['image_url']?.toString()),
        };
      }
    }
    return null;
  }
}

// ============================================================================
// HELPERS
// ============================================================================
Future<T> _withRetry<T>(
  Future<T> Function() fn, {
  required String label,
  int maxRetries = 1,
}) async {
  int attempt = 0;
  while (true) {
    try {
      return await fn().timeout(_kRequestTimeout);
    } on TimeoutException {
      attempt++;
      if (attempt > maxRetries) {
        debugPrint('[Messages] ❌ $label: timeout after $attempt attempts');
        throw TimeoutException('$label: délai dépassé');
      }
      debugPrint('[Messages] ⏱️ $label timeout — retry $attempt/$maxRetries');
      await Future.delayed(_kRetryDelay);
    } catch (e) {
      debugPrint('[Messages] ❌ $label error: $e');
      rethrow;
    }
  }
}

// ============================================================================
// PAGE PRINCIPALE
// ============================================================================
class MessagesPage extends ConsumerStatefulWidget {
  const MessagesPage({super.key});

  @override
  ConsumerState<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends ConsumerState<MessagesPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    debugPrint('[Messages] 💬 Page opened');
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    debugPrint('[Messages] 👋 Page disposed');
    super.dispose();
  }

  Future<void> _loadData() async {
    // ✅ FIX #1 : MessageProvider est un ChangeNotifier sans argument
    final provider = context.read<MessageProvider>();
    HapticFeedback.selectionClick();

    try {
      await Future.wait([
        _withRetry(() => provider.loadConversations(), label: 'loadConversations'),
        _withRetry(() => provider.loadDisputes(), label: 'loadDisputes'),
      ]);
      debugPrint('[Messages] ✓ All data loaded');
    } catch (e) {
      debugPrint('[Messages] ❌ Load error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // ✅ FIX #1 : Utiliser Provider (ChangeNotifier) au lieu de Riverpod ref.watch
    final messageProvider = context.watch<MessageProvider>();
    final displayCurrencyCode = ref.watch(currencyProvider);
    final currencyService = CurrencyService.instance;

    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      appBar: AppBar(
        title: Text(
          l10n.t('messages_title'),
          style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold, fontSize: 20, color: ThixPolicy.textMain),
        ),
        backgroundColor: ThixPolicy.card,
        elevation: 0,
        scrolledUnderElevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            // ✅ FIX #2 : Utiliser le widget Tab de Flutter (pas l'enum)
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.chat_rounded, size: 18),
                  const SizedBox(width: 8),
                  Text(l10n.t('messages_tab_conversations'), style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.semiBold)),
                  if (messageProvider.unreadCount > 0)
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: ThixPolicy.danger,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${messageProvider.unreadCount}',
                        style: ThixPolicy.microStyle.copyWith(fontSize: 10, color: Colors.white, fontWeight: ThixPolicy.bold),
                      ),
                    ),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.gavel_rounded, size: 18),
                  const SizedBox(width: 8),
                  Text(l10n.t('messages_tab_disputes'), style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.semiBold)),
                ],
              ),
            ),
          ],
          indicatorColor: ThixPolicy.primary,
          labelColor: ThixPolicy.primary,
          unselectedLabelColor: ThixPolicy.textSecondary,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: ThixPolicy.textMain),
            tooltip: l10n.t('common_refresh'),
            onPressed: _loadData,
          ),
          IconButton(
            icon: const Icon(Icons.phone_in_talk_rounded, color: ThixPolicy.textMain),
            tooltip: l10n.t('messages_voice_call'),
            onPressed: () => _startVoiceCall(),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildConversationsTab(messageProvider, l10n, displayCurrencyCode, currencyService),
          _buildDisputesTab(messageProvider, l10n),
        ],
      ),
    );
  }

  Widget _buildConversationsTab(
    MessageProvider provider,
    AppLocalizations l10n,
    String displayCurrencyCode,
    CurrencyService currencyService,
  ) {
    if (provider.isLoading) return const _SkeletonList();

    if (provider.conversations.isEmpty) {
      return _EmptyState(
        title: l10n.t('messages_no_conversations'),
        subtitle: l10n.t('messages_no_conversations_subtitle'),
        icon: Icons.chat_bubble_outline_rounded,
        actionLabel: l10n.t('messages_discover_shops'),
        onAction: () => context.push('/market/search'),
      );
    }

    return RefreshIndicator(
      color: ThixPolicy.primary,
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: provider.conversations.length,
        itemBuilder: (context, index) {
          final conv = provider.conversations[index];
          return _ConversationTile(
            conversation: conv,
            onTap: () => _openChatWithProductContext(conv, l10n, displayCurrencyCode, currencyService),
          );
        },
      ),
    );
  }

  Widget _buildDisputesTab(MessageProvider provider, AppLocalizations l10n) {
    if (provider.isLoadingDisputes) return const _SkeletonList();

    if (provider.disputes.isEmpty) {
      return _EmptyState(
        title: l10n.t('messages_no_disputes'),
        subtitle: l10n.t('messages_no_disputes_subtitle'),
        icon: Icons.gavel_rounded,
      );
    }

    return RefreshIndicator(
      color: ThixPolicy.primary,
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: provider.disputes.length,
        itemBuilder: (context, index) {
          final dispute = provider.disputes[index];
          return _DisputeCard(dispute: dispute, onTap: () => _openDispute(dispute['id']?.toString() ?? ''));
        },
      ),
    );
  }

  void _openChatWithProductContext(
    Map<String, dynamic> conversation,
    AppLocalizations l10n,
    String displayCurrencyCode,
    CurrencyService currencyService,
  ) {
    final convId = conversation['id']?.toString() ?? '';
    if (!_MessagesValidators.isValidId(convId)) {
      debugPrint('[Messages] ⚠️ Invalid conversation ID: $convId');
      return;
    }

    HapticFeedback.selectionClick();

    // ✅ FIX #3 : Appel correct de la méthode publique
    final productRef = _MessagesValidators.extractProductFromMetadata(conversation['metadata']);
    final otherUser = conversation['other_user'] as Map? ?? {};
    final userMap = Map<String, dynamic>.from(otherUser);

    final productData = productRef != null
        ? _buildProductData(productRef, displayCurrencyCode, currencyService)
        : null;

    final title = _MessagesValidators.sanitize(userMap['name']?.toString() ?? l10n.t('messages_default_chat_title'), maxLength: 60);
    final userName = _MessagesValidators.sanitize(userMap['name']?.toString() ?? '', maxLength: 60);
    final userAvatar = _MessagesValidators.sanitizeUrl(userMap['avatar']?.toString());

    context.push(
      '/market/chat/$convId',
      extra: {
        'title': title,
        'userName': userName,
        'userAvatar': userAvatar,
        'productContext': productData,
        'isProductChat': productData != null,
        // ✅ EXCEPTION THIX MARKET : lève la règle "connexion paire obligatoire"
        // dans ChatScreen et ChatPage pour les conversations acheteur ↔ vendeur
        'bypassConnection': true,
        'locale': Localizations.localeOf(context).languageCode,
      },
    );

    debugPrint('[Messages] 💬 Opened chat $convId with product: ${productData != null ? productData['title'] : 'none'}');
  }

  Map<String, dynamic>? _buildProductData(
    Map<String, dynamic> productRef,
    String displayCurrencyCode,
    CurrencyService currencyService,
  ) {
    final id = productRef['id']?.toString();
    final title = productRef['title']?.toString() ?? 'Produit';
    final priceInProductCurrency = productRef['price'] as double?;
    final productCurrencyCode = _MessagesValidators.normalizeCurrencyCode(productRef['currency']);
    final imageUrl = productRef['image_url'] as String?;

    if (id == null || !_MessagesValidators.isValidId(id)) return null;

    final convertedPrice = priceInProductCurrency != null
        ? currencyService.convert(priceInProductCurrency, from: productCurrencyCode, to: displayCurrencyCode)
        : null;
    final formattedPrice = convertedPrice != null
        ? currencyService.formatPrice(convertedPrice, currencyCode: displayCurrencyCode, lang: Localizations.localeOf(context).languageCode)
        : '';

    return {
      'id': id,
      'title': title,
      'price': priceInProductCurrency,
      'formatted_price': formattedPrice,
      'currency_code': productCurrencyCode,
      'display_currency': displayCurrencyCode,
      'is_converted': productCurrencyCode != displayCurrencyCode,
      'image_url': imageUrl,
    };
  }

  void _openDispute(String disputeId) {
    if (!_MessagesValidators.isValidId(disputeId)) {
      debugPrint('[Messages] ⚠️ Invalid dispute ID: $disputeId');
      return;
    }
    HapticFeedback.selectionClick();
    context.push('/market/dispute/$disputeId');
    debugPrint('[Messages] ⚖️ Opened dispute $disputeId');
  }

  void _startVoiceCall() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => const _VoiceCallSheet(),
    );
  }
}

// ============================================================================
// COMPOSANTS
// ============================================================================

class _ConversationTile extends StatelessWidget {
  final Map<String, dynamic> conversation;
  final VoidCallback onTap;

  const _ConversationTile({required this.conversation, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final lastMessage = _MessagesValidators.sanitize(conversation['last_message']?.toString(), maxLength: 100);
    final isUnread = ((conversation['unread_count'] as num?)?.toInt() ?? 0) > 0;
    final formattedTime = _MessagesValidators.formatDate(conversation['last_message_time']?.toString(), context);
    final otherUser = conversation['other_user'] as Map? ?? {};
    final userName = _MessagesValidators.sanitize(otherUser['name']?.toString() ?? l10n.t('messages_default_user'), maxLength: 60);
    final userAvatar = _MessagesValidators.sanitizeUrl(otherUser['avatar']?.toString());
    final isOnline = otherUser['is_online'] == true;
    final isTyping = conversation['is_typing'] == true;
    final unreadCount = (conversation['unread_count'] as num?)?.toInt() ?? 0;

    // ✅ FIX #3 : Appel correct de la méthode publique
    final hasProductContext = _MessagesValidators.extractProductFromMetadata(conversation['metadata']) != null;

    return Semantics(
      button: true,
      label: 'Conversation avec $userName, ${isUnread ? "non lue" : "lue"}, dernier message: $lastMessage',
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: isUnread ? ThixPolicy.primary.withOpacity(0.05) : ThixPolicy.card,
          child: Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: ThixPolicy.surfaceSoft,
                    backgroundImage: userAvatar != null ? CachedNetworkImageProvider(userAvatar) : null,
                    child: userAvatar == null
                        ? const Icon(Icons.person_rounded, size: 26, color: ThixPolicy.textMuted)
                        : null,
                  ),
                  if (isOnline)
                    Positioned(
                      bottom: 0, right: 0,
                      child: Container(
                        width: 12, height: 12,
                        decoration: BoxDecoration(color: ThixPolicy.success, shape: BoxShape.circle, border: Border.all(color: ThixPolicy.card, width: 2)),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(userName, style: ThixPolicy.labelStyle.copyWith(fontWeight: isUnread ? ThixPolicy.bold : ThixPolicy.regular, fontSize: 15, color: ThixPolicy.textMain), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                        if (formattedTime.isNotEmpty)
                          Text(formattedTime, style: ThixPolicy.captionStyle.copyWith(fontSize: 11, color: ThixPolicy.textMuted, fontWeight: isUnread ? ThixPolicy.semiBold : ThixPolicy.regular)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (isTyping)
                          SizedBox(width: 60, child: Text(l10n.t('messages_typing'), style: ThixPolicy.captionStyle.copyWith(fontSize: 12, color: ThixPolicy.primary, fontStyle: FontStyle.italic)))
                        else
                          Expanded(
                            child: Text(
                              lastMessage.isEmpty ? l10n.t('messages_no_message') : lastMessage,
                              style: ThixPolicy.captionStyle.copyWith(fontSize: 13, color: isUnread ? ThixPolicy.textMain : ThixPolicy.textSecondary, fontWeight: isUnread ? ThixPolicy.semiBold : ThixPolicy.regular),
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        if (unreadCount > 0)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: ThixPolicy.primary, borderRadius: BorderRadius.circular(10)),
                            child: Text('$unreadCount', style: ThixPolicy.microStyle.copyWith(fontSize: 11, color: Colors.white, fontWeight: ThixPolicy.bold)),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (hasProductContext)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Container(
                    width: 24, height: 24,
                    decoration: BoxDecoration(color: ThixPolicy.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                    child: const Icon(Icons.shopping_cart_outlined, size: 16, color: ThixPolicy.primary),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DisputeCard extends StatelessWidget {
  final Map<String, dynamic> dispute;
  final VoidCallback onTap;

  const _DisputeCard({required this.dispute, required this.onTap});

  static const Map<String, Color> _statusColors = {
    'open': ThixPolicy.gold, 'mediation': ThixPolicy.primary,
    'resolved': ThixPolicy.success, 'closed': ThixPolicy.textMuted,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final id = dispute['id']?.toString() ?? '';
    if (!_MessagesValidators.isValidId(id)) return const SizedBox.shrink();

    final status = dispute['status']?.toString() ?? 'open';
    final statusColor = _statusColors[status] ?? ThixPolicy.textMuted;
    final statusLabels = <String, String>{
      'open': l10n.t('messages_status_open'),
      'mediation': l10n.t('messages_status_mediation'),
      'resolved': l10n.t('messages_status_resolved'),
      'closed': l10n.t('messages_status_closed'),
    };
    final statusText = statusLabels[status] ?? l10n.t('messages_status_unknown');
    final reason = _MessagesValidators.sanitize(dispute['reason']?.toString(), maxLength: 200);
    final orderId = dispute['order_id']?.toString() ?? '';
    final createdDate = _MessagesValidators.formatFullDate(dispute['created_at']?.toString(), context);
    final lastMessage = _MessagesValidators.sanitize(dispute['last_message']?.toString(), maxLength: 100);

    return Semantics(
      button: true,
      label: 'Litige $id, statut $statusText, commande $orderId',
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: ThixPolicy.card, borderRadius: BorderRadius.circular(ThixPolicy.rMd),
          border: Border.all(color: ThixPolicy.border.withOpacity(0.6)), boxShadow: ThixPolicy.shadowSoft(opacity: 0.03),
        ),
        child: InkWell(
          onTap: onTap, borderRadius: BorderRadius.circular(ThixPolicy.rMd),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(l10n.t('messages_dispute_number', args: [id]), style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.bold, fontSize: 16, color: ThixPolicy.textMain)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                      child: Text(statusText, style: ThixPolicy.captionStyle.copyWith(color: statusColor, fontSize: 12, fontWeight: ThixPolicy.semiBold)),
                    ),
                  ],
                ),
                if (reason.isNotEmpty) ...[const SizedBox(height: 8), Text(reason, style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textSecondary))],
                const SizedBox(height: 8),
                Text(l10n.t('messages_order_number', args: [orderId]), style: ThixPolicy.captionStyle.copyWith(fontSize: 12, color: ThixPolicy.textMuted)),
                const SizedBox(height: 8),
                Row(children: [
                  const Icon(Icons.access_time_rounded, size: 14, color: ThixPolicy.textMuted),
                  const SizedBox(width: 4),
                  Text(l10n.t('messages_opened_on', args: [createdDate]), style: ThixPolicy.captionStyle.copyWith(fontSize: 12, color: ThixPolicy.textMuted)),
                ]),
                if (lastMessage.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: ThixPolicy.surfaceSoft, borderRadius: BorderRadius.circular(8)),
                    child: Row(children: [
                      const Icon(Icons.message_rounded, size: 14, color: ThixPolicy.textMuted),
                      const SizedBox(width: 8),
                      Expanded(child: Text(lastMessage, style: ThixPolicy.captionStyle.copyWith(fontSize: 12, color: ThixPolicy.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    ]),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VoiceCallSheet extends StatelessWidget {
  const _VoiceCallSheet();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: ThixPolicy.card, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: ThixPolicy.border, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: ThixPolicy.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.phone_in_talk_rounded, color: ThixPolicy.primary, size: 20)),
              const SizedBox(width: 10),
              Text(l10n.t('messages_voice_call_title'), style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.textMain)),
            ],
          ),
          const SizedBox(height: 8),
          Text(l10n.t('messages_voice_call_desc'), style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textMuted)),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(child: _ContactTile(role: l10n.t('messages_role_seller'), name: 'Jean Dupont', info: 'Électronique Pro', icon: Icons.store_rounded)),
            const SizedBox(width: 16),
            Expanded(child: _ContactTile(role: l10n.t('messages_role_buyer'), name: 'Marie Claire', info: l10n.t('messages_order_ref', args: ['#12345']), icon: Icons.shopping_bag_rounded)),
          ]),
          const SizedBox(height: 24),
          Semantics(
            button: true, label: l10n.t('messages_start_call'),
            child: ElevatedButton.icon(
              onPressed: () {
                HapticFeedback.mediumImpact();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Row(children: [const Icon(Icons.phone_in_talk_rounded, color: Colors.white, size: 20), const SizedBox(width: 8), Text(l10n.t('messages_feature_coming_soon'))]), backgroundColor: ThixPolicy.primary, behavior: SnackBarBehavior.floating));
              },
              icon: const Icon(Icons.call_rounded), label: Text(l10n.t('messages_start_call'), style: const TextStyle(fontWeight: ThixPolicy.bold)),
              style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
            ),
          ),
          const SizedBox(height: 16),
          Semantics(
            button: true, label: l10n.t('common_cancel'),
            child: TextButton(onPressed: () { HapticFeedback.selectionClick(); Navigator.pop(context); }, child: Text(l10n.t('common_cancel'), style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.textSecondary))),
          ),
        ],
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  final String role;
  final String name;
  final String info;
  final IconData icon;

  const _ContactTile({required this.role, required this.name, required this.info, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(border: Border.all(color: ThixPolicy.border), borderRadius: BorderRadius.circular(ThixPolicy.rMd)),
      child: Column(children: [
        Icon(icon, size: 32, color: ThixPolicy.primary),
        const SizedBox(height: 8),
        Text(role, style: ThixPolicy.captionStyle.copyWith(fontSize: 12, fontWeight: ThixPolicy.semiBold, color: ThixPolicy.textMain)),
        const SizedBox(height: 4),
        Text(name, style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.textMain)),
        const SizedBox(height: 2),
        Text(info, style: ThixPolicy.captionStyle.copyWith(fontSize: 11, color: ThixPolicy.textMuted)),
      ]),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _EmptyState({required this.title, required this.subtitle, required this.icon, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: ThixPolicy.textMuted.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, size: 64, color: ThixPolicy.textMuted)),
            const SizedBox(height: 16),
            Text(title, style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.textMain)),
            const SizedBox(height: 8),
            Text(subtitle, style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textMuted), textAlign: TextAlign.center),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              Semantics(button: true, label: actionLabel!, child: ElevatedButton(onPressed: onAction, style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))), child: Text(actionLabel!, style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.bold)))),
            ],
          ],
        ),
      ),
    );
  }
}

class _SkeletonList extends StatelessWidget {
  const _SkeletonList();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: 6,
      itemBuilder: (_, __) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          Container(width: 52, height: 52, decoration: BoxDecoration(color: Colors.grey.shade200, shape: BoxShape.circle)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(height: 14, width: 150, color: Colors.grey.shade200),
            const SizedBox(height: 8),
            Container(height: 12, width: 200, color: Colors.grey.shade200),
          ])),
        ]),
      ),
    );
  }
}
