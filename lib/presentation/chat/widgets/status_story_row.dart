// lib/presentation/chat/widgets/status_story_row.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:html/parser.dart' as html_parser;

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/models/chat/user_status_story.dart';
import 'package:thix_id/presentation/chat/providers/status_provider.dart';
import 'package:thix_id/presentation/chat/status/create_status_page.dart';
import 'package:thix_id/presentation/chat/status/status_viewer_page.dart';

// ============================================================================
// CONSTANTS (Format WhatsApp Cards Ajusté)
// ============================================================================
const double _kCardHeight = 135.0; // Réduit pour être moins imposant
const double _kCardWidth = 95.0;   // Réduit pour être plus compact
const double _kCardRadius = 12.0;  // Arrondi plus doux
const int _kMaxLabelLength = 20;

// ============================================================================
// VALIDATORS
// ============================================================================
class _StoryValidators {
  _StoryValidators._();

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

  static String safeFirstName(String? displayName, String fallback) {
    final name = sanitize(displayName, maxLength: 80);
    if (name.isEmpty) return fallback;
    final first = name.split(' ').first.trim();
    return first.isEmpty ? fallback : first;
  }
}

// ============================================================================
// STATUS STORY ROW (Format WhatsApp)
// ============================================================================
class StatusStoryRow extends ConsumerWidget {
  final String currentUserId;
  final String? currentUserAvatar;
  final String currentUserName;

  const StatusStoryRow({
    super.key,
    required this.currentUserId,
    this.currentUserAvatar,
    required this.currentUserName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(statusProvider);

    if (state.isLoading && state.items.isEmpty) {
      return const SizedBox(
        height: _kCardHeight,
        child: Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    final byUser = state.byUser;
    final ordered = state.orderedUserIds;
    final hasMine = ordered.any((id) => byUser[id]?.any((s) => s.isMine) == true);

    final safeCurrentUserAvatar = _StoryValidators.sanitizeUrl(currentUserAvatar);

    return SizedBox(
      height: _kCardHeight + 16, // +16 pour le padding vertical
      child: RepaintBoundary(
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: ordered.length + (hasMine ? 0 : 1),
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (ctx, i) {
            // 1. Bouton "Mon statut" (si pas encore de statut)
            if (!hasMine && i == 0) {
              return _StatusCard(
                label: l10n.t('status_my_status'),
                avatarUrl: safeCurrentUserAvatar,
                isAdd: true,
                hasUnseen: false,
                isMine: true,
                onTap: () {
                  HapticFeedback.selectionClick();
                  _openCreate(context);
                },
              );
            }

            // 2. Cartes des contacts
            final idx = hasMine ? i : i - 1;
            final userId = ordered[idx];
            final stories = byUser[userId] ?? [];
            if (stories.isEmpty) return const SizedBox.shrink();

            final first = stories.first;
            final isMine = first.isMine;
            final hasUnseen = stories.any((s) => !s.hasViewed && !s.isMine);

            final displayName = isMine
                ? l10n.t('status_my_status')
                : _StoryValidators.safeFirstName(first.displayName, 'User');

            final mediaUrl = _StoryValidators.sanitizeUrl(first.mediaUrl);
            final isVideo = first.mediaType == 'video';

            return _StatusCard(
              label: displayName,
              avatarUrl: _StoryValidators.sanitizeUrl(first.avatarUrl),
              mediaUrl: isVideo ? null : mediaUrl,
              textContent: first.content,
              background: first.background,
              hasUnseen: hasUnseen,
              isMine: isMine,
              onTap: () {
                HapticFeedback.selectionClick();
                _openViewer(context, stories);
              },
              onLongPress: isMine
                  ? () {
                      HapticFeedback.mediumImpact();
                      _openCreate(context);
                    }
                  : null,
            );
          },
        ),
      ),
    );
  }

  void _openCreate(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateStatusPage()));
  }

  void _openViewer(BuildContext context, List<UserStatusStory> stories) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => StatusViewerPage(stories: stories)));
  }
}

// ============================================================================
// WIDGET CARTE (Style WhatsApp Compact)
// ============================================================================
class _StatusCard extends StatelessWidget {
  final String label;
  final String? avatarUrl;
  final String? mediaUrl;
  final String? textContent;
  final String? background;
  final bool isAdd;
  final bool hasUnseen;
  final bool isMine;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _StatusCard({
    required this.label,
    this.avatarUrl,
    this.mediaUrl,
    this.textContent,
    this.background,
    this.isAdd = false,
    this.hasUnseen = false,
    this.isMine = false,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final safeLabel = _StoryValidators.sanitize(label, maxLength: _kMaxLabelLength);
    final borderColor = hasUnseen ? const Color(0xFF25D366) : Colors.transparent;

    Color bgColor = Colors.grey[300]!;
    if (background != null && background!.startsWith('#') && background!.length >= 7) {
      try {
        bgColor = Color(int.parse('FF${background!.replaceAll('#', '')}', radix: 16));
      } catch (_) {}
    }

    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          width: _kCardWidth,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_kCardRadius),
            border: Border.all(
              color: hasUnseen ? borderColor : Colors.black12,
              width: hasUnseen ? 2.0 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_kCardRadius - 2),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 1. Fond
                _buildBackground(bgColor),

                // 2. Dégradé noir en bas pour la lisibilité
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  height: 50,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.75),
                        ],
                      ),
                    ),
                  ),
                ),

                // 3. Bouton "+" pour Mon Statut
                if (isAdd)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: const Color(0xFF25D366),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: const Icon(Icons.add, size: 14, color: Colors.white),
                    ),
                  ),

                // 4. Nom du contact en bas
                Positioned(
                  bottom: 6,
                  left: 6,
                  right: 6,
                  child: Text(
                    safeLabel.isEmpty ? 'Statut' : safeLabel,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
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

  Widget _buildBackground(Color bgColor) {
    // 1. Bouton "Mon statut" (sans statut actif)
    if (isAdd) {
      return Container(
        color: const Color(0xFFF0F2F5),
        alignment: Alignment.center,
        child: CircleAvatar(
          radius: 24,
          backgroundColor: Colors.grey[300],
          backgroundImage: avatarUrl != null ? CachedNetworkImageProvider(avatarUrl!) : null,
          child: avatarUrl == null ? const Icon(Icons.person, color: Colors.grey, size: 24) : null,
        ),
      );
    }

    // 2. Statut avec Image
    if (mediaUrl != null) {
      return CachedNetworkImage(
        imageUrl: mediaUrl!,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(color: Colors.grey[300]),
        errorWidget: (_, __, ___) => Container(color: Colors.grey[400]),
      );
    }

    // 3. Statut Texte (Fond coloré + texte au centre)
    if (textContent != null && textContent!.isNotEmpty) {
      return Container(
        color: bgColor,
        padding: const EdgeInsets.all(8),
        alignment: Alignment.center,
        child: Text(
          textContent!,
          textAlign: TextAlign.center,
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    // Fallback
    return Container(color: Colors.grey[300]);
  }
}
