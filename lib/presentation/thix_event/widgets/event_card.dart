// lib/presentation/thix_event/widgets/event_card.dart
//
// EventCard — Production Enterprise (i18n + Sécurité + A11y)
//
// Features :
// - Intégration AppLocalizations (8 langues)
// - Traduction dynamique des catégories
// - Sanitization XSS sur tous les textes et URLs
// - Semantics complets pour a11y
// - Throttling anti-double-tap (500ms par event)
// - Logging structuré (_EventCardLogger)
// - Utilisation EventTheme + ThixPolicy
// - Fallback image robuste avec icône par catégorie
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/thix_design_policy.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/event_model.dart';

// ============================================================================
// EVENT THEME (adapté depuis ThixPolicy)
// ============================================================================
class EventTheme {
  static const Color bg = ThixPolicy.inkDeep;
  static const Color surface = Color(0xFF101B30);
  static const Color surfaceAlt = Color(0xFF14213A);
  static const Color border = Color(0xFF243451);
  static const Color primary = ThixPolicy.domainEvents;
  static const Color accent = ThixPolicy.gold;
  static const Color textMain = ThixPolicy.textOnDark;
  static const Color textSecondary = Color(0xFFA8B6CC);
  static const Color textMuted = Color(0xFF64748B);
  static const Color success = ThixPolicy.success;
}

// ============================================================================
// CONSTANTS
// ============================================================================
const Duration _kTapThrottle = Duration(milliseconds: 500);

// ============================================================================
// LOGGING
// ============================================================================
class _EventCardLogger {
  static const _tag = 'EventCard';
  static void info(String m, [Map<String, dynamic>? d]) => _log('INFO', m, d);
  static void warn(String m, [Map<String, dynamic>? d]) => _log('WARN', m, d);

  static void _log(String l, String m, Map<String, dynamic>? d) {
    if (!kDebugMode && l == 'INFO') return;
    final data = d != null
        ? ' ${d.entries.map((e) => '${e.key}=${e.value}').join(', ')}'
        : '';
    debugPrint('[$_tag] [$l] $m$data');
  }
}

// ============================================================================
// SANITIZER
// ============================================================================
class _Sanitizer {
  _Sanitizer._();

  static String text(String? input, {int maxLength = 200}) {
    if (input == null) return '';
    var s = input
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'javascript:', caseSensitive: false), '')
        .replaceAll(RegExp(r'on\w+\s*=', caseSensitive: false), '')
        .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '')
        .trim();
    if (s.length > maxLength) s = s.substring(0, maxLength);
    return s;
  }

  static String url(String? input) {
    if (input == null || input.isEmpty) return '';
    // Only allow http/https
    if (!input.startsWith('http://') && !input.startsWith('https://')) {
      return '';
    }
    // Remove any javascript: or data: injection attempts
    var s = input.replaceAll(RegExp(r'javascript:', caseSensitive: false), '');
    if (s.length > 2048) s = s.substring(0, 2048);
    return s;
  }
}

// ============================================================================
// CATEGORY KEY MAPPING (i18n)
// ============================================================================
String _categoryKey(String category) {
  switch (category.toLowerCase()) {
    case 'musique':
    case 'concert':
      return 'category_music';
    case 'conference':
      return 'category_conference';
    case 'culture':
      return 'category_culture';
    case 'sport':
    case 'match':
      return 'category_sport';
    case 'festival':
      return 'category_festival';
    case 'spectacle':
      return 'category_spectacle';
    case 'business':
      return 'category_business';
    case 'exposition':
      return 'category_exhibition';
    default:
      return 'category_other';
  }
}

/// Couleur d'accent par catégorie (tokens sémantiques)
Color _categoryAccent(String category) {
  switch (category.toLowerCase()) {
    case 'musique':
    case 'concert':
      return const Color(0xFF6B3BFF); // Violet musique
    case 'sport':
    case 'match':
      return ThixPolicy.success; // Vert sport
    case 'festival':
      return const Color(0xFFEC4899); // Rose festival
    case 'culture':
      return ThixPolicy.domainLearning; // Bleu culture
    case 'business':
      return ThixPolicy.domainJobs; // Vert business
    case 'conference':
      return ThixPolicy.domainInfo; // Bleu info
    default:
      return EventTheme.primary;
  }
}

/// Icône par catégorie
IconData _categoryIcon(String category) {
  switch (category.toLowerCase()) {
    case 'musique':
    case 'concert':
      return Icons.music_note_rounded;
    case 'sport':
    case 'match':
      return Icons.emoji_events_rounded;
    case 'festival':
      return Icons.celebration_rounded;
    case 'culture':
      return Icons.palette_rounded;
    case 'business':
      return Icons.business_center_rounded;
    case 'conference':
      return Icons.groups_rounded;
    case 'spectacle':
      return Icons.theater_comedy_rounded;
    default:
      return Icons.event_rounded;
  }
}

// ============================================================================
// WIDGET
// ============================================================================
class EventCard extends StatefulWidget {
  final Event event;
  final VoidCallback onTap;
  final bool isCompact;
  final VoidCallback? onShare;
  final VoidCallback? onFavoriteTap;

  const EventCard({
    super.key,
    required this.event,
    required this.onTap,
    this.isCompact = false,
    this.onShare,
    this.onFavoriteTap,
  });

  @override
  State<EventCard> createState() => _EventCardState();
}

class _EventCardState extends State<EventCard> {
  DateTime? _lastTap;
  DateTime? _lastFavTap;

  bool _canTap() {
    final now = DateTime.now();
    if (_lastTap != null && now.difference(_lastTap!) < _kTapThrottle) {
      _EventCardLogger.warn('Card tap throttled', {'id': widget.event.id});
      return false;
    }
    _lastTap = now;
    return true;
  }

  bool _canFavTap() {
    final now = DateTime.now();
    if (_lastFavTap != null && now.difference(_lastFavTap!) < _kTapThrottle) {
      return false;
    }
    _lastFavTap = now;
    return true;
  }

  void _handleTap() {
    if (!_canTap()) return;
    if (!mounted) return;
    HapticFeedback.selectionClick();
    _EventCardLogger.info('Card tapped', {'id': widget.event.id});
    widget.onTap();
  }

  void _handleFavTap() {
    if (!_canFavTap()) return;
    if (!mounted) return;
    if (widget.onFavoriteTap == null) return;
    HapticFeedback.lightImpact();
    _EventCardLogger.info('Favorite tapped', {'id': widget.event.id});
    widget.onFavoriteTap!();
  }

  void _handleShare() {
    if (!mounted) return;
    if (widget.onShare == null) return;
    HapticFeedback.lightImpact();
    _EventCardLogger.info('Share tapped', {'id': widget.event.id});
    widget.onShare!();
  }

  @override
  Widget build(BuildContext context) {
    return widget.isCompact ? _compact(context) : _grid(context);
  }

  // ════════════════════════════════════════════════════════════
  // GRID VIEW (carte complète)
  // ════════════════════════════════════════════════════════════
  Widget _grid(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final safeTitle = _Sanitizer.text(widget.event.title, maxLength: 100);
    final safeLocation = _Sanitizer.text(widget.event.location, maxLength: 100);
    final safeImageUrl = _Sanitizer.url(widget.event.imageUrl);
    final category = _Sanitizer.text(widget.event.category, maxLength: 30);
    final accent = _categoryAccent(category);
    final categoryLabel = l10n.t(_categoryKey(category));
    final icon = _categoryIcon(category);

    return Semantics(
      button: true,
      label: '$safeTitle, ${widget.event.shortDate}, $safeLocation, ${widget.event.formattedPrice}',
      child: GestureDetector(
        onTap: _handleTap,
        child: Container(
          decoration: BoxDecoration(
            color: EventTheme.surface,
            borderRadius: BorderRadius.circular(ThixPolicy.rLg),
            border: Border.all(color: EventTheme.border),
            boxShadow: ThixPolicy.shadowSoft(opacity: 0.15),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 1.25,
                    child: safeImageUrl.isNotEmpty
                        ? Image.network(
                            safeImageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _buildImageFallback(accent, icon),
                          )
                        : _buildImageFallback(accent, icon),
                  ),

                  // Badge catégorie
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(ThixPolicy.s8),
                      ),
                      child: Text(
                        categoryLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),

                  // Bouton favori
                  if (widget.onFavoriteTap != null)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Semantics(
                        button: true,
                        label: widget.event.isLiked
                            ? l10n.t('event_unfavorite')
                            : l10n.t('event_favorite'),
                        child: GestureDetector(
                          onTap: _handleFavTap,
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.45),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withOpacity(0.12),
                              ),
                            ),
                            child: Icon(
                              widget.event.isLiked
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              size: 14,
                              color: widget.event.isLiked
                                  ? EventTheme.primary
                                  : Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Badge GRATUIT
                  if (widget.event.isFree)
                    Positioned(
                      bottom: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: EventTheme.success,
                          borderRadius: BorderRadius.circular(ThixPolicy.s6),
                        ),
                        child: Text(
                          l10n.t('event_free'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),

                  // Badge prix
                  Positioned(
                    bottom: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(ThixPolicy.rSm),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.12),
                        ),
                      ),
                      child: Text(
                        widget.event.formattedPrice,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(ThixPolicy.s12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      safeTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: EventTheme.textMain,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 10,
                          color: EventTheme.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          widget.event.shortDate,
                          style: TextStyle(
                            color: EventTheme.textMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_rounded,
                          size: 10,
                          color: EventTheme.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            safeLocation,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: EventTheme.textMuted,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Semantics(
                      button: true,
                      label: l10n.t('event_book_now'),
                      child: SizedBox(
                        width: double.infinity,
                        height: 36,
                        child: ElevatedButton(
                          onPressed: _handleTap,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: Text(
                            l10n.t('event_book_now'),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  // COMPACT VIEW (liste horizontale)
  // ════════════════════════════════════════════════════════════
  Widget _compact(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final safeTitle = _Sanitizer.text(widget.event.title, maxLength: 80);
    final safeImageUrl = _Sanitizer.url(widget.event.imageUrl);
    final category = _Sanitizer.text(widget.event.category, maxLength: 30);
    final accent = _categoryAccent(category);
    final categoryLabel = l10n.t(_categoryKey(category));
    final icon = _categoryIcon(category);

    return Semantics(
      button: true,
      label: '$safeTitle, ${widget.event.shortDate}, ${widget.event.formattedPrice}',
      child: GestureDetector(
        onTap: _handleTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: ThixPolicy.s10),
          padding: const EdgeInsets.all(ThixPolicy.s10),
          decoration: BoxDecoration(
            color: EventTheme.surface,
            borderRadius: BorderRadius.circular(ThixPolicy.rMd),
            border: Border.all(color: EventTheme.border),
          ),
          child: Row(
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(ThixPolicy.rSm),
                    child: safeImageUrl.isNotEmpty
                        ? Image.network(
                            safeImageUrl,
                            width: 64,
                            height: 64,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _buildCompactFallback(accent, icon),
                          )
                        : _buildCompactFallback(accent, icon),
                  ),
                  if (widget.onFavoriteTap != null)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Semantics(
                        button: true,
                        label: widget.event.isLiked
                            ? l10n.t('event_unfavorite')
                            : l10n.t('event_favorite'),
                        child: GestureDetector(
                          onTap: _handleFavTap,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              widget.event.isLiked
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              size: 10,
                              color: widget.event.isLiked
                                  ? EventTheme.primary
                                  : Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: ThixPolicy.s10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(ThixPolicy.s6),
                        border: Border.all(color: accent.withOpacity(0.25)),
                      ),
                      child: Text(
                        categoryLabel,
                        style: TextStyle(
                          color: accent,
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      safeTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: EventTheme.textMain,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 9,
                          color: EventTheme.textMuted,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          widget.event.shortDate,
                          style: TextStyle(
                            color: EventTheme.textMuted,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: ThixPolicy.s8),
              Text(
                widget.event.formattedPrice,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  // FALLBACKS IMAGE
  // ════════════════════════════════════════════════════════════
  Widget _buildImageFallback(Color accent, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [accent.withOpacity(0.8), accent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Icon(icon, color: Colors.white54, size: 40),
    );
  }

  Widget _buildCompactFallback(Color accent, IconData icon) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: accent.withOpacity(0.2),
        borderRadius: BorderRadius.circular(ThixPolicy.rSm),
      ),
      child: Icon(icon, color: accent, size: 24),
    );
  }
}
