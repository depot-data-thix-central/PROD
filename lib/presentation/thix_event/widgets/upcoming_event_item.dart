// lib/presentation/thix_event/widgets/upcoming_event_item.dart
//
// UpcomingEventItem — Production Enterprise (i18n + Sécurité + A11y)
//
// Features :
// - Intégration AppLocalizations (8 langues)
// - Traduction dynamique des catégories
// - DateFormat avec locale utilisateur
// - Sanitization XSS sur title/location
// - Semantics complet pour a11y
// - Logging structuré (_UpcomingLogger)
// - Throttling anti-spam (500ms)
// - Utilisation ThixPolicy + EventTheme
// - Gestion robuste des dates invalides
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/thix_design_policy.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/event_model.dart';

// ============================================================================
// EVENT THEME (adapté depuis ThixPolicy - thème violet premium)
// ============================================================================
class EventTheme {
  // Couleurs principales pour le thème Upcoming Events (violet premium)
  static const Color primary = Color(0xFF6B3CE2); // Violet THIX
  static const Color darkText = Color(0xFF1E1B4B);
  static const Color mutedText = Color(0xFF8B8BA7);
  static const Color cardBorder = Color(0xFFEEE9FF);
  static const Color surface = Colors.white;
  
  // Utilise les tokens ThixPolicy quand disponible
  static const Color accent = ThixPolicy.gold;
  static const Color success = ThixPolicy.success;
}

// ============================================================================
// CONSTANTS
// ============================================================================
const Duration _kTapThrottle = Duration(milliseconds: 500);

// ============================================================================
// LOGGING
// ============================================================================
class _UpcomingLogger {
  static const _tag = 'UpcomingEventItem';
  static void info(String m, [Map<String, dynamic>? d]) => _log('INFO', m, d);
  static void warn(String m, [Map<String, dynamic>? d]) => _log('WARN', m, d);

  static void _log(String l, String m, Map<String, dynamic>? d) {
    if (!kDebugMode && l == 'INFO') return;
    final data = d != null ? ' ${d.entries.map((e) => '${e.key}=${e.value}').join(', ')}' : '';
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
}

// ============================================================================
// CATEGORY KEY MAPPING (i18n)
// ============================================================================
String _categoryKey(String category) {
  switch (category.toLowerCase()) {
    case 'musique':
    case 'concert':
      return 'category_music_short';
    case 'conference':
      return 'category_conference_short';
    case 'culture':
      return 'category_culture_short';
    case 'sport':
      return 'category_sport_short';
    case 'festival':
      return 'category_festival_short';
    case 'spectacle':
      return 'category_spectacle_short';
    case 'exposition':
      return 'category_exhibition_short';
    case 'business':
      return 'category_business_short';
    default:
      return 'category_other_short';
  }
}

// ============================================================================
// WIDGET
// ============================================================================
class UpcomingEventItem extends StatefulWidget {
  final Event event;
  final VoidCallback onTap;

  const UpcomingEventItem({
    super.key,
    required this.event,
    required this.onTap,
  });

  @override
  State<UpcomingEventItem> createState() => _UpcomingEventItemState();
}

class _UpcomingEventItemState extends State<UpcomingEventItem> {
  DateTime? _lastTap;

  bool _canTap() {
    final now = DateTime.now();
    if (_lastTap != null && now.difference(_lastTap!) < _kTapThrottle) {
      _UpcomingLogger.warn('Tap throttled');
      return false;
    }
    _lastTap = now;
    return true;
  }

  void _handleTap() {
    if (!_canTap()) return;
    
    if (!mounted) {
      _UpcomingLogger.warn('Widget not mounted on tap');
      return;
    }
    
    HapticFeedback.selectionClick();
    _UpcomingLogger.info('Event tapped', {'id': widget.event.id});
    widget.onTap();
  }

  /// Formatage sécurisé de la date avec fallback
  String _formatDate(DateTime date, String pattern, String locale) {
    try {
      return DateFormat(pattern, locale).format(date);
    } catch (e) {
      _UpcomingLogger.warn('Date format failed', {
        'pattern': pattern,
        'error': '$e',
      });
      // Fallback sur format basique
      try {
        return DateFormat(pattern, 'fr').format(date);
      } catch (_) {
        return date.toString();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    
    // Sanitize displayed text
    final safeTitle = _Sanitizer.text(widget.event.title, maxLength: 80);
    final safeLocation = _Sanitizer.text(widget.event.location, maxLength: 100);
    final safeCategory = _Sanitizer.text(widget.event.category, maxLength: 30);
    
    // Format dates with user locale
    final dayStr = _formatDate(widget.event.startDate, 'dd', locale);
    final monthStr = _formatDate(widget.event.startDate, 'MMM', locale).toUpperCase();
    final timeStr = _formatDate(widget.event.startDate, 'HH:mm', locale);
    
    // Category label via i18n
    final categoryKey = _categoryKey(safeCategory);
    final categoryLabel = l10n.t(categoryKey);

    return Semantics(
      button: true,
      label: '$safeTitle, $timeStr, $safeLocation, ${widget.event.formattedPrice}',
      child: GestureDetector(
        onTap: _handleTap,
        child: Container(
          margin: const EdgeInsets.symmetric(
            horizontal: ThixPolicy.s16,
            vertical: ThixPolicy.s6,
          ),
          padding: const EdgeInsets.all(ThixPolicy.s12),
          decoration: BoxDecoration(
            color: EventTheme.surface,
            borderRadius: BorderRadius.circular(ThixPolicy.rMd),
            border: Border.all(
              color: EventTheme.cardBorder,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: EventTheme.primary.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // ── BLOC DATE (Violet THIX) ──
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: EventTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(ThixPolicy.rSm),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      dayStr,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: EventTheme.primary,
                      ),
                    ),
                    Text(
                      monthStr,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: EventTheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: ThixPolicy.s14),
              
              // ── INFOS ÉVÉNEMENT ──
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Badge catégorie
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: ThixPolicy.s8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: EventTheme.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(ThixPolicy.s6),
                      ),
                      child: Text(
                        categoryLabel,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: EventTheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: ThixPolicy.s6),
                    
                    // Titre
                    Text(
                      safeTitle,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: EventTheme.darkText,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: ThixPolicy.s6),
                    
                    // Heure + Lieu
                    Row(
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 12,
                          color: EventTheme.mutedText,
                        ),
                        const SizedBox(width: ThixPolicy.s4),
                        Expanded(
                          child: Text(
                            '$timeStr • $safeLocation',
                            style: TextStyle(
                              fontSize: 11,
                              color: EventTheme.mutedText,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: ThixPolicy.s8),

              // ── BADGE PRIX ──
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: ThixPolicy.s12,
                  vertical: ThixPolicy.s8,
                ),
                decoration: BoxDecoration(
                  color: EventTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(ThixPolicy.rSm),
                ),
                child: Text(
                  widget.event.formattedPrice,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: EventTheme.primary,
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
