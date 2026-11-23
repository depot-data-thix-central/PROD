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
// CONSTANTS (Format Cinematic Gold — unique & premium)
// ============================================================================
const double _kCardHeight = 110.0;   // +cinématique
const double _kCardWidth  = 155.0;   // plus large = +impact visuel
const double _kCardRadius = 14.0;
const int    _kMaxLabelLength = 22;

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
// STATUS STORY ROW (Format Cinematic Gold)
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
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (ctx, i) {
            // 1. Bouton « Mon statut » (si pas encore de statut)
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
              storyCount: stories.length, // ✅ Badge « +N »
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
// WIDGET CARTE — Design « Cinematic Gold »
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
  final int storyCount; // Nombre de stories pour le badge « +N »
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
    this.storyCount = 1,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final safeLabel = _StoryValidators.sanitize(label, maxLength: _kMaxLabelLength);
    final accent = hasUnseen ? ThixPolicy.gold : Colors.white70;

    Color bgColor = const Color(0xFF1A1A1A);
    if (background != null && background!.startsWith('#') && background!.length >= 7) {
      try {
        bgColor = Color(int.parse('FF${background!.replaceAll('#', '')}', radix: 16));
      } catch (_) {}
    }

    return Semantics(
      button: true,
      label: '$label${hasUnseen ? " (nouveau statut)" : ""}',
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          width: _kCardWidth,
          height: _kCardHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_kCardRadius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.18),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
              if (hasUnseen)
                BoxShadow(
                  color: ThixPolicy.gold.withOpacity(0.35),
                  blurRadius: 10,
                  spreadRadius: -2,
                ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_kCardRadius),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // ---------- 1. Fond ----------
                _buildBackground(bgColor),

                // ---------- 2. Dégradé bas ----------
                Positioned(
                  left: 0, right: 0, bottom: 0, height: 62,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.15),
                          Colors.black.withOpacity(0.85),
                        ],
                        stops: const [0.0, 0.55, 1.0],
                      ),
                    ),
                  ),
                ),

                // ---------- 3. Border fine intérieure ----------
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(_kCardRadius),
                        border: Border.all(
                          color: hasUnseen
                              ? ThixPolicy.gold.withOpacity(0.9)
                              : Colors.white.withOpacity(0.08),
                          width: hasUnseen ? 1.8 : 1.0,
                        ),
                      ),
                    ),
                  ),
                ),

                // ---------- 4. Badge « +N » (multi-stories) ----------
                if (storyCount > 1 && !isAdd)
                  Positioned(
                    top: 7, right: 7,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.65),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.white24, width: 0.6),
                      ),
                      child: Text(
                        '+${storyCount - 1}',
                        style: const TextStyle(
                          fontSize: 9, fontWeight: FontWeight.w900,
                          color: Colors.white, letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),

                // ---------- 5. Badge « NEW » doré (accent or) ----------
                if (hasUnseen && !isMine && storyCount <= 1)
                  Positioned(
                    top: 7, right: 7,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: ThixPolicy.gold,
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [
                          BoxShadow(
                            color: ThixPolicy.gold.withOpacity(0.6),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: const Text(
                        'NEW',
                        style: TextStyle(
                          fontSize: 8, fontWeight: FontWeight.w900,
                          color: Colors.black, letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ),

                // ---------- 6. Avatar flottant (top-left) ----------
                if (!isAdd)
                  Positioned(
                    top: 7, left: 7,
                    child: Container(
                      width: 26, height: 26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: accent, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.35),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: avatarUrl != null
                            ? CachedNetworkImage(
                                imageUrl: avatarUrl!,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => Container(color: Colors.grey[800]),
                                errorWidget: (_, __, ___) => Container(
                                  color: Colors.grey[800],
                                  child: const Icon(Icons.person, size: 14, color: Colors.white70),
                                ),
                              )
                            : Container(
                                color: Colors.grey[800],
                                child: const Icon(Icons.person, size: 14, color: Colors.white70),
                              ),
                      ),
                    ),
                  ),

                // ---------- 7. Bouton « + » (Mon Statut / Add) ----------
                if (isAdd)
                  Positioned(
                    top: 8, right: 8,
                    child: Container(
                      width: 24, height: 24,
                      decoration: BoxDecoration(
                        color: ThixPolicy.gold,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.8),
                        boxShadow: [
                          BoxShadow(
                            color: ThixPolicy.gold.withOpacity(0.6),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.add, size: 14, color: Colors.black),
                    ),
                  ),

                // ---------- 8. Label (bas) ----------
                Positioned(
                  bottom: 7,
                  left: isAdd ? 8 : 38,
                  right: 8,
                  child: Text(
                    safeLabel.isEmpty ? 'Statut' : safeLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.1,
                      shadows: [
                        Shadow(blurRadius: 6, color: Colors.black87, offset: Offset(0, 1)),
                      ],
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

  // ---------- FOND ----------
  Widget _buildBackground(Color bgColor) {
    // 1) Bouton « Ajouter »
    if (isAdd) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              ThixPolicy.inkDeep,
              ThixPolicy.inkDeep.withOpacity(0.75),
              Colors.black,
            ],
          ),
        ),
        alignment: Alignment.center,
        child: Icon(
          Icons.add_circle_outline_rounded,
          size: 36,
          color: Colors.white.withOpacity(0.18),
        ),
      );
    }

    // 2) Photo
    if (mediaUrl != null) {
      return CachedNetworkImage(
        imageUrl: mediaUrl!,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(color: Colors.grey[850]),
        errorWidget: (_, __, ___) => Container(color: Colors.grey[900]),
      );
    }

    // 3) Texte
    if (textContent != null && textContent!.isNotEmpty) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [bgColor, Color.lerp(bgColor, Colors.black, 0.35)!],
          ),
        ),
        padding: const EdgeInsets.fromLTRB(10, 38, 10, 30),
        alignment: Alignment.center,
        child: Text(
          textContent!,
          textAlign: TextAlign.center,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            height: 1.3,
            shadows: [Shadow(blurRadius: 3, color: Colors.black54)],
          ),
        ),
      );
    }

    return Container(color: Colors.grey[850]);
  }
}
