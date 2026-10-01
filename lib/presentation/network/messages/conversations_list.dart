// lib/presentation/network/messages/conversations_list.dart
//
// ConversationsList — Production Enterprise
//
// Features production :
// - Logging structuré & Hook Sentry/Crashlytics
// - Internationalisation complète (i18n)
// - Sanitization XSS renforcée (récursive + blocage data:uri)
// - Accessibilité (Semantics) pour les lecteurs d'écran
// - Compatibility Flutter 3.27+ (Color.withValues au lieu de withOpacity)
// - Fix fuite mémoire (TextEditingController disposé correctement)
// - Gestion robuste des états vides et erreurs
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:html/parser.dart' as html_parser;

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/services/network_service.dart';

// ============================================================================
// LOGGING & MONITORING
// ============================================================================

class _ConversationsLogger {
  static const _tag = 'ConversationsList';
  static void info(String m, [Map<String, dynamic>? d]) => _log('INFO', m, d);
  static void warn(String m, [Map<String, dynamic>? d]) => _log('WARN', m, d);
  static void error(String m, [Map<String, dynamic>? d]) => _log('ERROR', m, d);

  static void _log(String level, String message, Map<String, dynamic>? data) {
    if (!kDebugMode && level == 'INFO') return;
    final dataStr = data != null
        ? ' ${data.entries.map((e) => '${e.key}=${e.value}').join(', ')}'
        : '';
    debugPrint('[$_tag] [$level] $message$dataStr');
  }
}

typedef ErrorReporter = void Function(
    String context, Object error, [StackTrace? stack]);

// ============================================================================
// VALIDATORS & SANITIZERS
// ============================================================================

class _ConversationsValidators {
  _ConversationsValidators._();

  static const Duration requestTimeout = Duration(seconds: 15);

  static String sanitize(String? input, {int maxLength = 200}) {
    if (input == null || input.trim().isEmpty) return '';
    
    // Suppression HTML récursive (anti-évasion)
    var s = input;
    String prev;
    do {
      prev = s;
      s = s.replaceAll(RegExp(r'<[^>]*>'), '');
    } while (s != prev);

    // Blocage vecteurs XSS
    s = s
        .replaceAll(RegExp(r'javascript:', caseSensitive: false), '')
        .replaceAll(RegExp(r'data:text/html', caseSensitive: false), '')
        .replaceAll(RegExp(r'on\w+\s*=', caseSensitive: false), '')
        .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '')
        .replaceAll(RegExp(r'[\u200B-\u200F\u202A-\u202E\u2060-\u206F]'), '')
        .trim();

    if (s.length > maxLength) {
      s = s.substring(0, maxLength);
    }
    return s;
  }

  static String? sanitizeUrl(String? url) {
    if (url == null || url.trim().isEmpty) return null;
    final trimmed = url.trim();
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      return null;
    }
    return trimmed.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
  }
}

// ============================================================================
// PROVIDER CONVERSATIONS
// ============================================================================

class ConversationsNotifier extends AsyncNotifier<List<Conversation>> {
  /// Hook optionnel pour Sentry/Crashlytics
  static ErrorReporter? onErrorReport;

  @override
  Future<List<Conversation>> build() async {
    final networkService = NetworkService(Supabase.instance.client);
    try {
      final convs = await networkService
          .getConversations()
          .timeout(_ConversationsValidators.requestTimeout);
      _ConversationsLogger.info('Loaded conversations', {'count': convs.length});
      return convs;
    } catch (e, stack) {
      _ConversationsLogger.error('Load conversations failed', {'error': '$e'});
      if (!kDebugMode) {
        onErrorReport?.call('load_conversations', e, stack);
      }
      rethrow;
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => build());
  }
}

final conversationsProvider =
    AsyncNotifierProvider<ConversationsNotifier, List<Conversation>>(
  ConversationsNotifier.new,
);

// ============================================================================
// PAGE PRINCIPALE
// ============================================================================

class ConversationsList extends ConsumerStatefulWidget {
  const ConversationsList({super.key});

  @override
  ConsumerState<ConversationsList> createState() => _ConversationsListState();
}

class _ConversationsListState extends ConsumerState<ConversationsList> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final conversationsAsync = ref.watch(conversationsProvider);

    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      appBar: AppBar(
        backgroundColor: ThixPolicy.card,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          l10n.t('conversations_title'),
          style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: ThixPolicy.textMain, size: 20),
          onPressed: () {
            HapticFeedback.selectionClick();
            context.pop();
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded,
                color: ThixPolicy.textMain, size: 22),
            onPressed: () => _showSearchDialog(),
            tooltip: l10n.t('common_search'),
          ),
        ],
      ),
      body: conversationsAsync.when(
        loading: () => _buildSkeleton(),
        error: (e, _) => _buildErrorState(e.toString()),
        data: (conversations) {
          final filtered = _searchQuery.isEmpty
              ? conversations
              : conversations.where((c) {
                  final name = c.otherUserName.toLowerCase();
                  return name.contains(_searchQuery.toLowerCase());
                }).toList();

          if (filtered.isEmpty) {
            return _searchQuery.isEmpty
                ? _buildEmptyState()
                : _buildNoResults();
          }

          return RefreshIndicator(
            color: ThixPolicy.primary,
            onRefresh: () => ref.read(conversationsProvider.notifier).refresh(),
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(12),
              itemCount: filtered.length,
              itemBuilder: (context, index) =>
                  _buildConversationTile(filtered[index]),
            ),
          );
        },
      ),
    );
  }

  void _showSearchDialog() {
    final l10n = AppLocalizations.of(context);
    final searchController = TextEditingController(text: _searchQuery);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThixPolicy.card,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ThixPolicy.rLg)),
        title: Row(
          children: [
            const Icon(Icons.search_rounded,
                color: ThixPolicy.primary, size: 24),
            const SizedBox(width: 12),
            Text(l10n.t('conversations_search_title'),
                style:
                    ThixPolicy.titleStyle.copyWith(fontWeight: ThixPolicy.bold)),
          ],
        ),
        content: TextField(
          controller: searchController,
          autofocus: true,
          onChanged: (v) => setState(() => _searchQuery = v),
          style: ThixPolicy.bodyStyle,
          decoration: InputDecoration(
            hintText: l10n.t('conversations_search_hint'),
            hintStyle: ThixPolicy.bodySmallStyle
                .copyWith(color: ThixPolicy.textMuted),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(ThixPolicy.rMd)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(ThixPolicy.rMd),
              borderSide:
                  const BorderSide(color: ThixPolicy.primary, width: 1.5),
            ),
            filled: true,
            fillColor: ThixPolicy.surfaceSoft,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _searchQuery = '');
            },
            child: Text(l10n.t('common_clear'),
                style: ThixPolicy.labelStyle
                    .copyWith(color: ThixPolicy.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
                backgroundColor: ThixPolicy.primary,
                foregroundColor: Colors.white),
            child: Text(l10n.t('common_close')),
          ),
        ],
      ),
    ).then((_) {
      // ✅ Fix fuite mémoire : disposal du controller à la fermeture
      searchController.dispose();
    });
  }

  Widget _buildSkeleton() {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 8,
      itemBuilder: (_, __) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: ThixPolicy.card,
          borderRadius: BorderRadius.circular(ThixPolicy.rMd),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                  color: Colors.grey.shade200, shape: BoxShape.circle),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 14, width: 120, color: Colors.grey.shade200),
                  const SizedBox(height: 8),
                  Container(height: 12, width: 200, color: Colors.grey.shade200),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: ThixPolicy.danger.withValues(alpha: 0.1),
                  shape: BoxShape.circle),
              child: const Icon(Icons.error_outline_rounded,
                  size: 56, color: ThixPolicy.danger),
            ),
            const SizedBox(height: 20),
            Text(l10n.t('conversations_load_error'),
                style:
                    ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold)),
            const SizedBox(height: 8),
            Text(
              _ConversationsValidators.sanitize(error),
              textAlign: TextAlign.center,
              style: ThixPolicy.bodyStyle
                  .copyWith(color: ThixPolicy.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => ref.invalidate(conversationsProvider),
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              label: Text(l10n.t('common_retry')),
              style: ElevatedButton.styleFrom(
                backgroundColor: ThixPolicy.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(ThixPolicy.rFull)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                  color: ThixPolicy.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle),
              child: const Icon(Icons.chat_bubble_outline_rounded,
                  size: 64, color: ThixPolicy.primary),
            ),
            const SizedBox(height: 24),
            Text(l10n.t('conversations_empty_title'),
                style:
                    ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold)),
            const SizedBox(height: 8),
            Text(
              l10n.t('conversations_empty_subtitle'),
              textAlign: TextAlign.center,
              style: ThixPolicy.bodyStyle.copyWith(
                  color: ThixPolicy.textSecondary, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResults() {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: ThixPolicy.surfaceStrong, shape: BoxShape.circle),
              child: const Icon(Icons.search_off_rounded,
                  size: 56, color: ThixPolicy.textMuted),
            ),
            const SizedBox(height: 20),
            Text(l10n.t('conversations_no_results_title'),
                style:
                    ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold)),
            const SizedBox(height: 8),
            Text(
              l10n.t('conversations_no_results_subtitle', args: [_searchQuery]),
              textAlign: TextAlign.center,
              style: ThixPolicy.bodyStyle.copyWith(
                  color: ThixPolicy.textSecondary, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConversationTile(Conversation conversation) {
    final l10n = AppLocalizations.of(context);
    final avatarUrl =
        _ConversationsValidators.sanitizeUrl(conversation.otherUserAvatar);
    final name = _ConversationsValidators.sanitize(
        conversation.otherUserName,
        maxLength: 50);
    final lastMessage = _ConversationsValidators.sanitize(
        conversation.lastMessage,
        maxLength: 100);
    final unreadCount = conversation.unreadCount;
    final hasUnread = unreadCount > 0;

    return Semantics(
      button: true,
      label: 'Conversation avec $name',
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: ThixPolicy.card,
          borderRadius: BorderRadius.circular(ThixPolicy.rMd),
          border: Border.all(color: ThixPolicy.border.withValues(alpha: 0.5)),
          boxShadow: ThixPolicy.shadowSoft(opacity: 0.03),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(ThixPolicy.rMd),
            onTap: () {
              HapticFeedback.selectionClick();
              context.push(
                '/network/chat/${conversation.otherUserId}',
                extra: conversation.otherUserName,
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Avatar avec bordure
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: ThixPolicy.border, width: 1.5),
                    ),
                    child: CircleAvatar(
                      radius: 28,
                      backgroundColor: ThixPolicy.surfaceSoft,
                      backgroundImage: avatarUrl != null
                          ? CachedNetworkImageProvider(avatarUrl)
                          : null,
                      child: avatarUrl == null
                          ? Text(
                              name.isNotEmpty ? name[0].toUpperCase() : '?',
                              style: ThixPolicy.h3Style.copyWith(
                                color: ThixPolicy.textSecondary,
                                fontWeight: ThixPolicy.bold,
                              ),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Nom + dernier message
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                name,
                                style: ThixPolicy.labelStyle.copyWith(
                                  fontWeight: hasUnread
                                      ? ThixPolicy.bold
                                      : ThixPolicy.semiBold,
                                  color: ThixPolicy.textMain,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              timeago.format(conversation.lastMessageAt,
                                  locale: 'fr'),
                              style: ThixPolicy.microStyle.copyWith(
                                color: ThixPolicy.textMuted,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          lastMessage.isEmpty
                              ? l10n.t('conversations_no_message')
                              : lastMessage,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: ThixPolicy.captionStyle.copyWith(
                            color: hasUnread
                                ? ThixPolicy.textMain
                                : ThixPolicy.textSecondary,
                            fontWeight: hasUnread
                                ? ThixPolicy.semiBold
                                : ThixPolicy.regular,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Badge non lu
                  if (hasUnread)
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [ThixPolicy.gold, Color(0xFFFFA500)],
                        ),
                        borderRadius: BorderRadius.circular(ThixPolicy.rFull),
                        boxShadow: [
                          BoxShadow(
                            color: ThixPolicy.gold.withValues(alpha: 0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        '$unreadCount',
                        style: ThixPolicy.microStyle.copyWith(
                          color: Colors.white,
                          fontWeight: ThixPolicy.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
