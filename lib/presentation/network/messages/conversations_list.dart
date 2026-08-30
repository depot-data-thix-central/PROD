// lib/presentation/network/messages/conversations_list.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:html/parser.dart' as html_parser;

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/services/network_service.dart';

// ============================================================================
// VALIDATEURS
// ============================================================================
class _ConversationsValidators {
  _ConversationsValidators._();

  static const Duration requestTimeout = Duration(seconds: 15);

  static String sanitize(String? input, {int maxLength = 200}) {
    if (input == null || input.trim().isEmpty) return '';
    final doc = html_parser.parse(input);
    var sanitized = doc.body?.text ?? input;
    sanitized = sanitized
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'javascript:', caseSensitive: false), '')
        .replaceAll(RegExp(r'on\w+\s*=', caseSensitive: false), '')
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        .trim();
    return sanitized.length > maxLength ? sanitized.substring(0, maxLength) : sanitized;
  }

  static String? sanitizeUrl(String? url) {
    if (url == null || url.trim().isEmpty) return null;
    final trimmed = url.trim();
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) return null;
    return trimmed.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
  }
}

// ============================================================================
// PROVIDER CONVERSATIONS
// ============================================================================
class ConversationsNotifier extends AsyncNotifier<List<Conversation>> {
  @override
  Future<List<Conversation>> build() async {
    final networkService = NetworkService(Supabase.instance.client);
    try {
      final convs = await networkService
          .getConversations()
          .timeout(_ConversationsValidators.requestTimeout);
      debugPrint('[Conversations] Loaded ${convs.length} conversations');
      return convs;
    } catch (e) {
      debugPrint('[Conversations] Load error: $e');
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
    final conversationsAsync = ref.watch(conversationsProvider);

    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      appBar: AppBar(
        backgroundColor: ThixPolicy.card,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Messages',
          style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: ThixPolicy.textMain, size: 20),
          onPressed: () {
            HapticFeedback.selectionClick();
            context.pop();
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded, color: ThixPolicy.textMain, size: 22),
            onPressed: () => _showSearchDialog(),
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
            return _searchQuery.isEmpty ? _buildEmptyState() : _buildNoResults();
          }

          return RefreshIndicator(
            color: ThixPolicy.primary,
            onRefresh: () => ref.read(conversationsProvider.notifier).refresh(),
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(12),
              itemCount: filtered.length,
              itemBuilder: (context, index) => _buildConversationTile(filtered[index]),
            ),
          );
        },
      ),
    );
  }

  void _showSearchDialog() {
    final searchController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ThixPolicy.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rLg)),
        title: Row(
          children: [
            const Icon(Icons.search_rounded, color: ThixPolicy.primary, size: 24),
            const SizedBox(width: 12),
            Text('Rechercher', style: ThixPolicy.titleStyle.copyWith(fontWeight: ThixPolicy.bold)),
          ],
        ),
        content: TextField(
          controller: searchController,
          autofocus: true,
          onChanged: (v) => setState(() => _searchQuery = v),
          style: ThixPolicy.bodyStyle,
          decoration: InputDecoration(
            hintText: 'Nom de la personne...',
            hintStyle: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.textMuted),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(ThixPolicy.rMd)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(ThixPolicy.rMd),
              borderSide: const BorderSide(color: ThixPolicy.primary, width: 1.5),
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
            child: Text('Effacer', style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.primary, foregroundColor: Colors.white),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
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
              decoration: BoxDecoration(color: Colors.grey.shade200, shape: BoxShape.circle),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: ThixPolicy.danger.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.error_outline_rounded, size: 56, color: ThixPolicy.danger),
            ),
            const SizedBox(height: 20),
            Text('Erreur de chargement', style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold)),
            const SizedBox(height: 8),
            Text(
              _ConversationsValidators.sanitize(error),
              textAlign: TextAlign.center,
              style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => ref.invalidate(conversationsProvider),
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              label: const Text('Réessayer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: ThixPolicy.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rFull)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: ThixPolicy.primary.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.chat_bubble_outline_rounded, size: 64, color: ThixPolicy.primary),
            ),
            const SizedBox(height: 24),
            Text('Aucune conversation', style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold)),
            const SizedBox(height: 8),
            Text(
              'Envoyez un message à quelqu\'un pour commencer une conversation',
              textAlign: TextAlign.center,
              style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textSecondary, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: ThixPolicy.surfaceStrong, shape: BoxShape.circle),
              child: const Icon(Icons.search_off_rounded, size: 56, color: ThixPolicy.textMuted),
            ),
            const SizedBox(height: 20),
            Text('Aucun résultat', style: ThixPolicy.h3Style.copyWith(fontWeight: ThixPolicy.bold)),
            const SizedBox(height: 8),
            Text(
              'Aucune conversation ne correspond à "$_searchQuery"',
              textAlign: TextAlign.center,
              style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.textSecondary, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConversationTile(Conversation conversation) {
    final avatarUrl = _ConversationsValidators.sanitizeUrl(conversation.otherUserAvatar);
    final name = _ConversationsValidators.sanitize(conversation.otherUserName, maxLength: 50);
    final lastMessage = _ConversationsValidators.sanitize(conversation.lastMessage, maxLength: 100);
    final unreadCount = conversation.unreadCount;
    final hasUnread = unreadCount > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: ThixPolicy.card,
        borderRadius: BorderRadius.circular(ThixPolicy.rMd),
        border: Border.all(color: ThixPolicy.border.withOpacity(0.5)),
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
                    backgroundImage: avatarUrl != null ? CachedNetworkImageProvider(avatarUrl) : null,
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
                                fontWeight: hasUnread ? ThixPolicy.bold : ThixPolicy.semiBold,
                                color: ThixPolicy.textMain,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            timeago.format(conversation.lastMessageAt, locale: 'fr'),
                            style: ThixPolicy.microStyle.copyWith(
                              color: ThixPolicy.textMuted,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        lastMessage.isEmpty ? 'Aucun message' : lastMessage,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ThixPolicy.captionStyle.copyWith(
                          color: hasUnread ? ThixPolicy.textMain : ThixPolicy.textSecondary,
                          fontWeight: hasUnread ? ThixPolicy.semiBold : ThixPolicy.regular,
                        ),
                      ),
                    ],
                  ),
                ),

                // Badge non lu
                if (hasUnread)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [ThixPolicy.gold, Color(0xFFFFA500)],
                      ),
                      borderRadius: BorderRadius.circular(ThixPolicy.rFull),
                      boxShadow: [
                        BoxShadow(
                          color: ThixPolicy.gold.withOpacity(0.3),
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
    );
  }
}
