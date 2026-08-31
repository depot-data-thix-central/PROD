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
// CONSTANTS
// ============================================================================
const double _kStoryHeight = 98.0;
const double _kAvatarRadius = 26.0;
const double _kRingPadding = 2.5;
const double _kAddBadgeSize = 20.0;
const double _kAddBadgeBorder = 2.0;
const double _kLabelWidth = 64.0;
const int _kMaxLabelLength = 15;

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

  /// Retourne le prénom de manière sûre (jamais de crash sur string vide)
  static String safeFirstName(String? displayName, String fallback) {
    final name = sanitize(displayName, maxLength: 80);
    if (name.isEmpty) return fallback;
    final first = name.split(' ').first.trim();
    return first.isEmpty ? fallback : first;
  }

  /// Initiale sûre pour avatar fallback
  static String safeInitial(String? name) {
    final s = sanitize(name, maxLength: 10);
    if (s.isEmpty) return '?';
    return s[0].toUpperCase();
  }
}

// ============================================================================
// STATUS STORY ROW
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
      return SizedBox(
        height: _kStoryHeight,
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2, color: ThixPolicy.primary),
          ),
        ),
      );
    }

    final byUser = state.byUser;
    final ordered = state.orderedUserIds;
    final hasMine = ordered.any((id) => byUser[id]?.any((s) => s.isMine) == true);

    final safeCurrentUserAvatar = _StoryValidators.sanitizeUrl(currentUserAvatar);

    return SizedBox(
      height: _kStoryHeight,
      child: RepaintBoundary(
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          itemCount: ordered.length + (hasMine ? 0 : 1),
          separatorBuilder: (_, __) => const SizedBox(width: 14),
          itemBuilder: (ctx, i) {
            // Bouton "Mon statut" toujours en premier si pas encore de statut
            if (!hasMine && i == 0) {
              return _StatusAvatar(
                label: l10n.t('status_my_status'),
                avatarUrl: safeCurrentUserAvatar,
                isAdd: true,
                hasUnseen: false,
                semanticsLabel: l10n.t('status_add_status'),
                onTap: () {
                  HapticFeedback.selectionClick();
                  _openCreate(context);
                },
              );
            }

            final idx = hasMine ? i : i - 1;
            final userId = ordered[idx];
            final stories = byUser[userId] ?? [];
            if (stories.isEmpty) return const SizedBox.shrink();

            final first = stories.first;
            final isMine = first.isMine;
            final hasUnseen = stories.any((s) => !s.hasViewed && !s.isMine);

            final displayName = isMine
                ? l10n.t('status_my_status')
                : _StoryValidators.safeFirstName(
                    first.displayName,
                    _StoryValidators.safeInitial(first.displayName),
                  );
            final safeAvatar = _StoryValidators.sanitizeUrl(first.avatarUrl);

            final semanticsLabel = isMine
                ? (hasUnseen
                    ? l10n.t('status_my_status_unseen')
                    : l10n.t('status_my_status_seen'))
                : (hasUnseen
                    ? l10n.t('status_user_unseen', args: [displayName])
                    : l10n.t('status_user_seen', args: [displayName]));

            return _StatusAvatar(
              label: displayName,
              avatarUrl: safeAvatar,
              isAdd: isMine && stories.isEmpty,
              hasUnseen: hasUnseen,
              isMine: isMine,
              semanticsLabel: semanticsLabel,
              onTap: () {
                HapticFeedback.selectionClick();
                if (isMine && stories.isEmpty) {
                  _openCreate(context);
                } else {
                  _openViewer(context, stories);
                }
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
    debugPrint('[StatusStory] ➕ Opening create status page');
    Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateStatusPage()));
  }

  void _openViewer(BuildContext context, List<UserStatusStory> stories) {
    debugPrint('[StatusStory] 👁️ Opening viewer with ${stories.length} stories');
    Navigator.push(context, MaterialPageRoute(builder: (_) => StatusViewerPage(stories: stories)));
  }
}

// ============================================================================
// STATUS AVATAR
// ============================================================================
class _StatusAvatar extends StatelessWidget {
  final String label;
  final String? avatarUrl;
  final bool isAdd;
  final bool hasUnseen;
  final bool isMine;
  final String semanticsLabel;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _StatusAvatar({
    required this.label,
    this.avatarUrl,
    this.isAdd = false,
    this.hasUnseen = false,
    this.isMine = false,
    required this.semanticsLabel,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // Couleurs du ring selon état
    final ringColor = hasUnseen
        ? ThixPolicy.gold
        : (isMine ? ThixPolicy.primary : ThixPolicy.border);

    final safeLabel = _StoryValidators.sanitize(label, maxLength: _kMaxLabelLength);

    return Semantics(
      button: true,
      label: semanticsLabel,
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                // Ring gradient/coloré
                Container(
                  padding: const EdgeInsets.all(_kRingPadding),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: hasUnseen || isMine
                        ? LinearGradient(
                            colors: hasUnseen
                                ? [ThixPolicy.gold, ThixPolicy.gold.withOpacity(0.6)]
                                : [ThixPolicy.primary, ThixPolicy.primary.withOpacity(0.6)],
                          )
                        : null,
                    color: hasUnseen || isMine ? null : ringColor,
                  ),
                  child: CircleAvatar(
                    radius: _kAvatarRadius,
                    backgroundColor: ThixPolicy.tint,
                    backgroundImage: avatarUrl != null
                        ? CachedNetworkImageProvider(avatarUrl!)
                        : null,
                    child: avatarUrl == null
                        ? Icon(
                            isAdd ? Icons.add : Icons.person_rounded,
                            color: ThixPolicy.primaryDeep,
                            size: isAdd ? 26 : 22,
                          )
                        : null,
                  ),
                ),
                // Badge "+" pour ajouter statut
                if (isAdd || isMine)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: _kAddBadgeSize,
                      height: _kAddBadgeSize,
                      decoration: BoxDecoration(
                        color: ThixPolicy.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: ThixPolicy.card, width: _kAddBadgeBorder),
                      ),
                      child: const Icon(Icons.add, size: 14, color: Colors.white),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: _kLabelWidth,
              child: Text(
                safeLabel.isEmpty ? l10n.t('status_unknown') : safeLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: ThixPolicy.captionStyle.copyWith(
                  fontSize: 11,
                  fontWeight: ThixPolicy.bold,
                  color: ThixPolicy.textMain,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
