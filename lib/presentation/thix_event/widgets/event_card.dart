// lib/presentation/thix_event/widgets/event_card.dart
//
// EventCard — Production Enterprise (i18n + Sécurité + A11y + États complets)
//
// Features :
// - Affichage aligné : Organisateur, Date + Heure, Lieu
// - Gestion complète des états : Pré-commande, Complet, Annulé, Reporté
// - Intégration AppLocalizations (8 langues)
// - Sanitization XSS sur tous les textes et URLs
// - Semantics complets pour a11y
// - Throttling anti-double-tap (500ms)
// - Fallback image robuste avec icône par catégorie

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/thix_design_policy.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/event_model.dart';

// ============================================================================
// EVENT THEME
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
  static const Color warning = Colors.orangeAccent; // 🟠 Pré-commande / Reporté / File d'attente
  static const Color danger = Color(0xFFEF4444);    // 🔴 Complet / Annulé
}

// ============================================================================
// CONSTANTS & LOGGING
// ============================================================================
const Duration _kTapThrottle = Duration(milliseconds: 500);

class _EventCardLogger {
  static const _tag = 'EventCard';
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

  static String url(String? input) {
    if (input == null || input.isEmpty) return '';
    if (!input.startsWith('http://') && !input.startsWith('https://')) return '';
    var s = input.replaceAll(RegExp(r'javascript:', caseSensitive: false), '');
    if (s.length > 2048) s = s.substring(0, 2048);
    return s;
  }
}

// ============================================================================
// HELPERS
// ============================================================================
String _categoryKey(String category) {
  final cat = category.toLowerCase().trim();
  if (cat.isEmpty || cat == 'plein air' || cat == 'libre' || cat == 'outdoor') return 'category_outdoor';
  switch (cat) {
    case 'musique': case 'concert': return 'category_music';
    case 'conference': return 'category_conference';
    case 'culture': return 'category_culture';
    case 'sport': case 'match': return 'category_sport';
    case 'festival': return 'category_festival';
    case 'spectacle': return 'category_spectacle';
    case 'business': return 'category_business';
    case 'exposition': return 'category_exhibition';
    default: return 'category_other';
  }
}

Color _categoryAccent(String category) {
  final cat = category.toLowerCase().trim();
  if (cat.isEmpty || cat == 'plein air' || cat == 'libre' || cat == 'outdoor') return ThixPolicy.success;
  switch (cat) {
    case 'musique': case 'concert': return const Color(0xFF6B3BFF);
    case 'sport': case 'match': return ThixPolicy.success;
    case 'festival': return const Color(0xFFEC4899);
    case 'culture': return ThixPolicy.domainLearning;
    case 'business': return ThixPolicy.domainJobs;
    case 'conference': return ThixPolicy.domainInfo;
    default: return EventTheme.primary;
  }
}

IconData _categoryIcon(String category) {
  final cat = category.toLowerCase().trim();
  if (cat.isEmpty || cat == 'plein air' || cat == 'libre' || cat == 'outdoor') return Icons.park_rounded;
  switch (cat) {
    case 'musique': case 'concert': return Icons.music_note_rounded;
    case 'sport': case 'match': return Icons.emoji_events_rounded;
    case 'festival': return Icons.celebration_rounded;
    case 'culture': return Icons.palette_rounded;
    case 'business': return Icons.business_center_rounded;
    case 'conference': return Icons.groups_rounded;
    case 'spectacle': return Icons.theater_comedy_rounded;
    default: return Icons.event_rounded;
  }
}

String _formatDateTime(DateTime? date, String locale) {
  if (date == null) return 'Date non définie';
  try {
    return DateFormat('dd MMM • HH:mm', locale).format(date);
  } catch (_) {
    return DateFormat('dd MMM • HH:mm', 'fr').format(date);
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
    if (_lastFavTap != null && now.difference(_lastFavTap!) < _kTapThrottle) return false;
    _lastFavTap = now;
    return true;
  }

  void _handleTap() {
    if (!_canTap() || !mounted) return;
    HapticFeedback.selectionClick();
    _EventCardLogger.info('Card tapped', {'id': widget.event.id});
    widget.onTap();
  }

  void _handleFavTap() {
    if (!_canFavTap() || !mounted || widget.onFavoriteTap == null) return;
    HapticFeedback.lightImpact();
    _EventCardLogger.info('Favorite tapped', {'id': widget.event.id});
    widget.onFavoriteTap!();
  }

  @override
  Widget build(BuildContext context) {
    return widget.isCompact ? _compact(context) : _grid(context);
  }

  // ════════════════════════════════════════════════════════════
  // GRID VIEW (Carte complète)
  // ════════════════════════════════════════════════════════════
  Widget _grid(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;

    final safeTitle = _Sanitizer.text(widget.event.title, maxLength: 100);
    final safeLocation = _Sanitizer.text(widget.event.location, maxLength: 100);
    final safeOrganizer = _Sanitizer.text(widget.event.organizerName, maxLength: 60);
    final safeImageUrl = _Sanitizer.url(widget.event.imageUrl);
    final category = _Sanitizer.text(widget.event.category, maxLength: 30);
    
    final bool isOutdoorOrFree = category.isEmpty || 
        category.toLowerCase() == 'plein air' || 
        category.toLowerCase() == 'libre' || 
        category.toLowerCase() == 'outdoor' ||
        widget.event.capacity == 0;

    final accent = _categoryAccent(category);
    final categoryLabel = category.isEmpty ? 'Plein air' : l10n.t(_categoryKey(category));
    final icon = _categoryIcon(category);

    // 🟢 Logique d'état complète
    final isCancelled = widget.event.status == 'cancelled';
    final isPostponed = widget.event.status == 'postponed';
    final isPreOrder = widget.event.ticketOpeningDate != null && DateTime.now().isBefore(widget.event.ticketOpeningDate!);
    final isSoldOut = !isOutdoorOrFree && (widget.event.remainingTickets ?? 0) <= 0;
    
    final bool useQueue = isSoldOut || (isPreOrder && widget.event.enableWaitingQueue);

    return Semantics(
      button: true,
      label: '$safeTitle, ${_formatDateTime(widget.event.startDate, locale)}, $safeLocation',
      child: GestureDetector(
        onTap: _handleTap,
        child: Container(
          decoration: BoxDecoration(
            color: EventTheme.surface,
            borderRadius: BorderRadius.circular(ThixPolicy.rLg),
            border: Border.all(color: isCancelled ? EventTheme.danger.withOpacity(0.5) : EventTheme.border),
            boxShadow: ThixPolicy.shadowSoft(opacity: isCancelled ? 0.05 : 0.15),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  // Image avec filtre si annulé/reporté
                  AspectRatio(
                    aspectRatio: 1.25,
                    child: safeImageUrl.isNotEmpty
                        ? ColorFiltered(
                            colorFilter: isCancelled || isPostponed 
                                ? const ColorFilter.matrix([0.3, 0, 0, 0, 0,  0, 0.3, 0, 0, 0,  0, 0, 0.3, 0, 0,  0, 0, 0, 1, 0])
                                : const ColorFilter.matrix([1, 0, 0, 0, 0,  0, 1, 0, 0, 0,  0, 0, 1, 0, 0,  0, 0, 0, 1, 0]),
                            child: Image.network(safeImageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _buildImageFallback(accent, icon)),
                          )
                        : _buildImageFallback(accent, icon),
                  ),

                  // Overlay "ANNULÉ" ou "REPORTÉ" massif
                  if (isCancelled || isPostponed)
                    Positioned.fill(
                      child: Container(
                        color: (isCancelled ? EventTheme.danger : EventTheme.warning).withOpacity(0.85),
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(isCancelled ? Icons.cancel_rounded : Icons.update_rounded, color: Colors.white, size: 28),
                              const SizedBox(width: 8),
                              Text(
                                isCancelled ? 'ANNULÉ' : 'REPORTÉ',
                                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 1.5),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // Badges supérieurs (si pas annulé/reporté)
                  if (!isCancelled && !isPostponed) ...[
                    Positioned(
                      top: 10, left: 10,
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: accent.withOpacity(0.9), borderRadius: BorderRadius.circular(ThixPolicy.s8)),
                            child: Text(categoryLabel, style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.w800)),
                          ),
                          if (isSoldOut) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              decoration: BoxDecoration(color: EventTheme.danger.withOpacity(0.9), borderRadius: BorderRadius.circular(ThixPolicy.s8)),
                              child: const Text('COMPLET', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900)),
                            ),
                          ] else if (isPreOrder) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              decoration: BoxDecoration(color: EventTheme.warning.withOpacity(0.9), borderRadius: BorderRadius.circular(ThixPolicy.s8)),
                              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(Icons.hourglass_top_rounded, size: 9, color: Colors.black),
                                SizedBox(width: 3),
                                Text('PRÉ-COMMANDE', style: TextStyle(color: Colors.black, fontSize: 8, fontWeight: FontWeight.w900)),
                              ]),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],

                  // Bouton favori
                  if (widget.onFavoriteTap != null && !isCancelled)
                    Positioned(
                      top: 10, right: 10,
                      child: Semantics(
                        button: true,
                        label: widget.event.isLiked ? l10n.t('event_unfavorite') : l10n.t('event_favorite'),
                        child: GestureDetector(
                          onTap: _handleFavTap,
                          child: Container(
                            width: 30, height: 30,
                            decoration: BoxDecoration(color: Colors.black.withOpacity(0.45), shape: BoxShape.circle, border: Border.all(color: Colors.white.withOpacity(0.12))),
                            child: Icon(widget.event.isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded, size: 14, color: widget.event.isLiked ? EventTheme.primary : Colors.white),
                          ),
                        ),
                      ),
                    ),

                  // Badge GRATUIT / PLEIN AIR
                  if ((widget.event.isFree || isOutdoorOrFree) && !isCancelled)
                    Positioned(
                      bottom: 10, left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(color: EventTheme.success, borderRadius: BorderRadius.circular(ThixPolicy.s6)),
                        child: Text(
                          isOutdoorOrFree && widget.event.isFree ? 'PLEIN AIR / LIBRE' : (isOutdoorOrFree ? 'PLEIN AIR' : l10n.t('event_free')),
                          style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),

                  // Badge prix
                  Positioned(
                    bottom: 10, right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(ThixPolicy.rSm), border: Border.all(color: Colors.white.withOpacity(0.12))),
                      child: Text(widget.event.formattedPrice, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
              
              // ── CONTENU ALIGNÉ ──
              Padding(
                padding: const EdgeInsets.all(ThixPolicy.s12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Titre
                    Text(safeTitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: EventTheme.textMain, fontSize: 14, fontWeight: FontWeight.w800, height: 1.2)),
                    const SizedBox(height: 10),
                    
                    // Organisateur
                    Row(
                      children: [
                        const Icon(Icons.badge_rounded, size: 12, color: EventTheme.textMuted),
                        const SizedBox(width: 6),
                        Expanded(child: Text(safeOrganizer.isEmpty ? 'Organisateur inconnu' : safeOrganizer, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: EventTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w600))),
                      ],
                    ),
                    const SizedBox(height: 6),
                    
                    // Date et Heure
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded, size: 12, color: EventTheme.textMuted),
                        const SizedBox(width: 6),
                        Text(_formatDateTime(widget.event.startDate, locale), style: const TextStyle(color: EventTheme.textMain, fontSize: 11, fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    
                    // Lieu
                    Row(
                      children: [
                        const Icon(Icons.location_on_rounded, size: 12, color: EventTheme.textMuted),
                        const SizedBox(width: 6),
                        Expanded(child: Text(safeLocation.isEmpty ? 'Lieu non défini' : safeLocation, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: EventTheme.textSecondary, fontSize: 11))),
                      ],
                    ),
                    
                    const SizedBox(height: 14),
                    
                    // 🟢 Bouton d'action dynamique
                    Semantics(
                      button: true,
                      label: isCancelled ? 'Événement annulé' : (useQueue ? 'File d\'attente' : (isPreOrder ? 'Pré-commande' : 'Réserver')),
                      child: SizedBox(
                        width: double.infinity,
                        height: 40,
                        child: ElevatedButton(
                          onPressed: isCancelled ? null : _handleTap,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isCancelled 
                                ? EventTheme.danger.withOpacity(0.2) 
                                : (useQueue ? EventTheme.warning : Colors.white),
                            foregroundColor: isCancelled ? EventTheme.danger : Colors.black,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (isCancelled) const Icon(Icons.cancel_rounded, size: 16),
                              if (isPostponed) const Icon(Icons.update_rounded, size: 16),
                              if (isCancelled || isPostponed) const SizedBox(width: 6),
                              Text(
                                isCancelled 
                                    ? 'ANNULÉ' 
                                    : (isPostponed ? 'VOIR DÉTAILS' : (isSoldOut ? "FILE D'ATTENTE" : (isPreOrder && widget.event.enableWaitingQueue ? "PRÉ-COMMANDE" : l10n.t('event_book_now')))),
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                              ),
                            ],
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
  // COMPACT VIEW (Liste horizontale)
  // ════════════════════════════════════════════════════════════
  Widget _compact(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;

    final safeTitle = _Sanitizer.text(widget.event.title, maxLength: 80);
    final safeOrganizer = _Sanitizer.text(widget.event.organizerName, maxLength: 40);
    final safeImageUrl = _Sanitizer.url(widget.event.imageUrl);
    final category = _Sanitizer.text(widget.event.category, maxLength: 30);
    
    final bool isOutdoorOrFree = category.isEmpty || category.toLowerCase() == 'plein air' || category.toLowerCase() == 'libre' || category.toLowerCase() == 'outdoor' || widget.event.capacity == 0;
    final accent = _categoryAccent(category);
    final categoryLabel = category.isEmpty ? 'Plein air' : l10n.t(_categoryKey(category));
    final icon = _categoryIcon(category);

    final isCancelled = widget.event.status == 'cancelled';
    final isPostponed = widget.event.status == 'postponed';
    final isPreOrder = widget.event.ticketOpeningDate != null && DateTime.now().isBefore(widget.event.ticketOpeningDate!);
    final isSoldOut = !isOutdoorOrFree && (widget.event.remainingTickets ?? 0) <= 0;

    return Semantics(
      button: true,
      label: '$safeTitle, ${_formatDateTime(widget.event.startDate, locale)}',
      child: GestureDetector(
        onTap: _handleTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: ThixPolicy.s10),
          padding: const EdgeInsets.all(ThixPolicy.s10),
          decoration: BoxDecoration(
            color: EventTheme.surface,
            borderRadius: BorderRadius.circular(ThixPolicy.rMd),
            border: Border.all(color: isCancelled ? EventTheme.danger.withOpacity(0.5) : EventTheme.border),
          ),
          child: Row(
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(ThixPolicy.rSm),
                    child: safeImageUrl.isNotEmpty
                        ? ColorFiltered(
                            colorFilter: isCancelled || isPostponed 
                                ? const ColorFilter.matrix([0.3, 0, 0, 0, 0,  0, 0.3, 0, 0, 0,  0, 0, 0.3, 0, 0,  0, 0, 0, 1, 0])
                                : const ColorFilter.matrix([1, 0, 0, 0, 0,  0, 1, 0, 0, 0,  0, 0, 1, 0, 0,  0, 0, 0, 1, 0]),
                            child: Image.network(safeImageUrl, width: 72, height: 72, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _buildCompactFallback(accent, icon)),
                          )
                        : _buildCompactFallback(accent, icon),
                  ),
                  // Overlay compact pour annulé
                  if (isCancelled || isPostponed)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(color: (isCancelled ? EventTheme.danger : EventTheme.warning).withOpacity(0.8), borderRadius: BorderRadius.circular(ThixPolicy.rSm)),
                        child: Center(child: Icon(isCancelled ? Icons.cancel_rounded : Icons.update_rounded, color: Colors.white, size: 24)),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: ThixPolicy.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Ligne 1: Catégorie + Statut
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: accent.withOpacity(0.15), borderRadius: BorderRadius.circular(ThixPolicy.s6), border: Border.all(color: accent.withOpacity(0.25))),
                          child: Text(categoryLabel, style: TextStyle(color: accent, fontSize: 8, fontWeight: FontWeight.w800)),
                        ),
                        if (isSoldOut) ...[
                          const SizedBox(width: 6),
                          Container(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2), decoration: BoxDecoration(color: EventTheme.danger.withOpacity(0.2), borderRadius: BorderRadius.circular(ThixPolicy.s6)), child: const Text('COMPLET', style: TextStyle(color: EventTheme.danger, fontSize: 7, fontWeight: FontWeight.w900))),
                        ] else if (isPreOrder) ...[
                          const SizedBox(width: 6),
                          Container(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2), decoration: BoxDecoration(color: EventTheme.warning.withOpacity(0.2), borderRadius: BorderRadius.circular(ThixPolicy.s6)), child: const Text('PRÉ-COMMANDE', style: TextStyle(color: EventTheme.warning, fontSize: 7, fontWeight: FontWeight.w900))),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Ligne 2: Titre
                    Text(safeTitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: EventTheme.textMain, fontSize: 13, fontWeight: FontWeight.w800, height: 1.2)),
                    const SizedBox(height: 6),
                    // Ligne 3: Organisateur
                    Row(
                      children: [
                        const Icon(Icons.badge_rounded, size: 10, color: EventTheme.textMuted),
                        const SizedBox(width: 4),
                        Expanded(child: Text(safeOrganizer.isEmpty ? 'Organisateur inconnu' : safeOrganizer, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: EventTheme.textSecondary, fontSize: 10))),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Ligne 4: Date + Prix
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded, size: 10, color: EventTheme.textMuted),
                            const SizedBox(width: 4),
                            Text(_formatDateTime(widget.event.startDate, locale), style: const TextStyle(color: EventTheme.textMuted, fontSize: 10, fontWeight: FontWeight.w600)),
                          ],
                        ),
                        Text(widget.event.formattedPrice, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900)),
                      ],
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
  // FALLBACKS IMAGE
  // ════════════════════════════════════════════════════════════
  Widget _buildImageFallback(Color accent, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [accent.withOpacity(0.8), accent], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Icon(icon, color: Colors.white54, size: 40),
    );
  }

  Widget _buildCompactFallback(Color accent, IconData icon) {
    return Container(
      width: 72, height: 72,
      decoration: BoxDecoration(color: accent.withOpacity(0.2), borderRadius: BorderRadius.circular(ThixPolicy.rSm)),
      child: Icon(icon, color: accent, size: 28),
    );
  }
}
