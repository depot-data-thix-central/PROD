// lib/presentation/chat/widgets/status_story_row.dart
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
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
// DESIGN « THIX HALO »
// 1 arc = 1 statut · or = non vu · gris = vu · pointillé = ajouter
// ============================================================================
const double _kAvatar = 54.0;
const double _kRing = 68.0;
const double _kStroke = 2.6;
const double _kItemWidth = 76.0;
const double _kRowHeight = 106.0;
const int _kMaxSegments = 20;
const int _kMaxLabelLength = 20;

// ============================================================================
// VALIDATORS (noms / URLs : mono-ligne volontaire)
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
// ROW
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

    if (state.isLoading && state.items.isEmpty) return const _HaloSkeleton();

    final byUser = state.byUser;
    final ordered = state.orderedUserIds;
    final hasMine = ordered.any((id) => byUser[id]?.any((s) => s.isMine) == true);
    final safeMeAvatar = _StoryValidators.sanitizeUrl(currentUserAvatar);

    return SizedBox(
      height: _kRowHeight,
      child: RepaintBoundary(
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: ordered.length + (hasMine ? 0 : 1),
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (ctx, i) {
            // « Mon statut » sans statut actif → anneau pointillé + badge +
            if (!hasMine && i == 0) {
              return _HaloItem(
                label: l10n.t('status_my_status'),
                avatarUrl: safeMeAvatar,
                isAdd: true,
                badge: const _PlusBadge(),
                onTap: () {
                  HapticFeedback.selectionClick();
                  _openCreate(context);
                },
              );
            }

            final idx = hasMine ? i : i - 1;
            final userId = ordered[idx];
            final stories = byUser[userId] ?? const <UserStatusStory>[];
            if (stories.isEmpty) return const SizedBox.shrink();

            final first = stories.first;
            final isMine = first.isMine;
            final mediaUrl = _StoryValidators.sanitizeUrl(first.mediaUrl);
            final String? txt = first.content;
            final isText = mediaUrl == null &&
                first.mediaType != 'video' &&
                txt != null &&
                txt.trim().isNotEmpty;

            // Monogramme coloré (statut texte sans avatar)
            Color? mono;
            if (isText) {
              final String? bg = first.background;
              if (bg != null && bg.startsWith('#')) {
                final hex = bg.replaceAll('#', '');
                if (hex.length >= 6) {
                  try {
                    mono = Color(int.parse('FF${hex.substring(0, 6)}', radix: 16));
                  } catch (_) {}
                }
              }
              mono ??= ThixPolicy.inkDeep;
            }

            // Badge : + (moi) / ▶ (vidéo) / Aa (texte)
            Widget? badge;
            VoidCallback? onBadgeTap;
            if (isMine) {
              badge = const _PlusBadge();
              onBadgeTap = () {
                HapticFeedback.selectionClick();
                _openCreate(context);
              };
            } else if (first.mediaType == 'video') {
              badge = const _TypeBadge(icon: Icons.play_arrow_rounded);
            } else if (isText) {
              badge = const _TypeBadge(label: 'Aa');
            }

            return _HaloItem(
              label: isMine
                  ? l10n.t('status_my_status')
                  : _StoryValidators.safeFirstName(first.displayName, 'User'),
              avatarUrl: _StoryValidators.sanitizeUrl(first.avatarUrl),
              segments: stories
                  .take(_kMaxSegments)
                  .map((s) => isMine ? false : s.hasViewed)
                  .toList(),
              monogramColor: mono,
              badge: badge,
              onBadgeTap: onBadgeTap,
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
// ITEM « HALO »
// ============================================================================
class _HaloItem extends StatelessWidget {
  final String label;
  final String? avatarUrl;
  final List<bool> segments; // true = vu (gris), false = non vu (or)
  final bool isAdd;
  final Color? monogramColor;
  final Widget? badge;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onBadgeTap;

  const _HaloItem({
    required this.label,
    this.avatarUrl,
    this.segments = const [],
    this.isAdd = false,
    this.monogramColor,
    this.badge,
    required this.onTap,
    this.onLongPress,
    this.onBadgeTap,
  });

  @override
  Widget build(BuildContext context) {
    final safeLabel = _StoryValidators.sanitize(label, maxLength: _kMaxLabelLength);
    final letter = safeLabel.isEmpty
        ? '?'
        : String.fromCharCode(safeLabel.runes.first).toUpperCase();

    Widget? fallback;
    if (avatarUrl == null) {
      fallback = monogramColor != null
          ? Text(letter,
              style: const TextStyle(
                  color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800))
          : const Icon(Icons.person_rounded, size: 26, color: ThixPolicy.textSecondary);
    }

    return Semantics(
      button: true,
      label: safeLabel,
      child: SizedBox(
        width: _kItemWidth,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
            width: _kRing,
            height: _kRing,
            child: Stack(clipBehavior: Clip.none, children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: isAdd
                      ? _DashedRingPainter(color: ThixPolicy.textMuted.withOpacity(0.55))
                      : _HaloRingPainter(
                          viewed: segments,
                          active: ThixPolicy.gold,
                          activeLight: Color.lerp(ThixPolicy.gold, Colors.white, 0.45)!,
                          seen: ThixPolicy.border,
                        ),
                ),
              ),
              Center(
                child: CircleAvatar(
                  radius: _kAvatar / 2,
                  backgroundColor: monogramColor ?? ThixPolicy.tint,
                  backgroundImage:
                      avatarUrl != null ? CachedNetworkImageProvider(avatarUrl!) : null,
                  child: fallback,
                ),
              ),
              Positioned.fill(
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onTap,
                    onLongPress: onLongPress,
                  ),
                ),
              ),
              if (badge != null)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onBadgeTap,
                    child: badge!,
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 5),
          Text(
            safeLabel.isEmpty ? '—' : safeLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: ThixPolicy.textMain),
          ),
        ]),
      ),
    );
  }
}

// ============================================================================
// BADGES
// ============================================================================
class _PlusBadge extends StatelessWidget {
  const _PlusBadge();
  @override
  Widget build(BuildContext context) => Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: ThixPolicy.gold,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.6),
        ),
        child: const Icon(Icons.add_rounded, size: 14, color: ThixPolicy.inkDeep),
      );
}

class _TypeBadge extends StatelessWidget {
  final IconData? icon;
  final String? label;
  const _TypeBadge({this.icon, this.label});
  @override
  Widget build(BuildContext context) => Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          color: ThixPolicy.inkDeep,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.4),
        ),
        child: icon != null
            ? Icon(icon, size: 11, color: Colors.white)
            : Center(
                child: Text(label ?? '',
                    style: const TextStyle(
                        fontSize: 8, fontWeight: FontWeight.w800, color: Colors.white, height: 1)),
              ),
      );
}

// ============================================================================
// PAINTERS
// ============================================================================
class _HaloRingPainter extends CustomPainter {
  final List<bool> viewed;
  final Color active;
  final Color activeLight;
  final Color seen;
  final double stroke;

  _HaloRingPainter({
    required this.viewed,
    required this.active,
    required this.activeLight,
    required this.seen,
    this.stroke = _kStroke,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final n = viewed.length;
    if (n == 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - stroke) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final gap = n == 1 ? 0.0 : math.min(0.18, 1.1 / n);
    final sweep = (2 * math.pi - gap * n) / n;

    final shader = SweepGradient(
      colors: [active, activeLight, active],
      transform: const GradientRotation(-math.pi / 2),
    ).createShader(rect);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    var start = -math.pi / 2;
    for (var i = 0; i < n; i++) {
      if (viewed[i]) {
        paint
          ..shader = null
          ..color = seen;
      } else {
        paint.shader = shader;
      }
      canvas.drawArc(rect, start + gap / 2, sweep, false, paint);
      start += sweep + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _HaloRingPainter old) =>
      !listEquals(old.viewed, viewed) ||
      old.active != active ||
      old.seen != seen ||
      old.stroke != stroke;
}

class _DashedRingPainter extends CustomPainter {
  final Color color;
  final double stroke;
  _DashedRingPainter({required this.color, this.stroke = 1.8});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - stroke) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    const dashes = 16;
    const step = 2 * math.pi / dashes;
    for (var i = 0; i < dashes; i++) {
      canvas.drawArc(rect, -math.pi / 2 + i * step, step * 0.5, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRingPainter old) =>
      old.color != color || old.stroke != stroke;
}

// ============================================================================
// SKELETON (chargement)
// ============================================================================
class _HaloSkeleton extends StatelessWidget {
  const _HaloSkeleton();
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _kRowHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: 6,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, __) => SizedBox(
          width: _kItemWidth,
          child: Column(children: [
            Container(
              width: _kRing,
              height: _kRing,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: ThixPolicy.border, width: _kStroke),
              ),
            ),
            const SizedBox(height: 7),
            Container(
              width: 44,
              height: 9,
              decoration:
                  BoxDecoration(color: ThixPolicy.tint, borderRadius: BorderRadius.circular(4)),
            ),
          ]),
        ),
      ),
    );
  }
}
