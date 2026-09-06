// lib/presentation/thix_event/widgets/category_chip.dart
//
// CategoryChip & CategoryChipsList — Production Enterprise
//
// Features :
// - Intégration AppLocalizations (8 langues)
// - Traduction dynamique des labels de catégorie
// - Utilisation EventTheme + ThixPolicy
// - Semantics complets (selected state pour lecteurs d'écran)
// - Throttling anti-spam (300ms)
// - Haptic feedback (selectionClick)
// - Chip "Tous" pour reset du filtre
// - Logging structuré (_CategoryChipLogger)
// - reduceMotion awareness
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/thix_design_policy.dart';
import '../../../l10n/app_localizations.dart';

// ============================================================================
// EVENT THEME (adapté depuis ThixPolicy)
// ============================================================================
class EventTheme {
  static const Color surface = Color(0xFF101B30);
  static const Color border = Color(0xFF243451);
  static const Color borderStrong = Color(0xFF334155);
  static const Color primary = ThixPolicy.domainEvents;
  static const Color textSecondary = Color(0xFFA8B6CC);
  static const Color textMain = ThixPolicy.textOnDark;
}

// ============================================================================
// CONSTANTS
// ============================================================================
const Duration _kTapThrottle = Duration(milliseconds: 300);

// ============================================================================
// LOGGING
// ============================================================================
class _CategoryChipLogger {
  static const _tag = 'CategoryChip';
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
// CATEGORY KEY MAPPING (i18n)
// ============================================================================
String _categoryKey(String slug) {
  switch (slug.toLowerCase()) {
    case 'all':
      return 'category_chip_all';
    case 'musique':
    case 'concert':
      return 'category_chip_music';
    case 'conference':
      return 'category_chip_conference';
    case 'culture':
      return 'category_chip_culture';
    case 'sport':
    case 'match':
      return 'category_chip_sport';
    case 'festival':
      return 'category_chip_festival';
    case 'spectacle':
      return 'category_chip_spectacle';
    case 'business':
      return 'category_chip_business';
    case 'exposition':
      return 'category_chip_exhibition';
    default:
      return 'category_chip_other';
  }
}

// ============================================================================
// CATEGORY CHIP (StatefulWidget pour throttling)
// ============================================================================
class CategoryChip extends StatefulWidget {
  final String label;
  final String slug;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const CategoryChip({
    super.key,
    required this.label,
    required this.slug,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<CategoryChip> createState() => _CategoryChipState();
}

class _CategoryChipState extends State<CategoryChip> {
  DateTime? _lastTap;

  bool _canTap() {
    final now = DateTime.now();
    if (_lastTap != null && now.difference(_lastTap!) < _kTapThrottle) {
      _CategoryChipLogger.warn('Chip tap throttled', {'slug': widget.slug});
      return false;
    }
    _lastTap = now;
    return true;
  }

  void _handleTap() {
    if (!_canTap()) return;
    if (!mounted) {
      _CategoryChipLogger.warn('Chip tap on unmounted widget');
      return;
    }
    
    HapticFeedback.selectionClick();
    _CategoryChipLogger.info('Chip tapped', {
      'slug': widget.slug,
      'wasSelected': widget.isSelected,
    });
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final reduceMotion = mediaQuery.accessibleNavigation ||
        mediaQuery.disableAnimations;

    return Semantics(
      button: true,
      selected: widget.isSelected,
      label: widget.label,
      child: GestureDetector(
        onTap: _handleTap,
        child: AnimatedContainer(
          duration: reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(
            horizontal: ThixPolicy.s14,
            vertical: ThixPolicy.s8,
          ),
          margin: const EdgeInsets.only(right: ThixPolicy.s8),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? EventTheme.primary.withOpacity(0.14)
                : EventTheme.surface,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: widget.isSelected
                  ? EventTheme.primary
                  : EventTheme.borderStrong,
              width: widget.isSelected ? 1.2 : 1,
            ),
            boxShadow: widget.isSelected
                ? [
                    BoxShadow(
                      color: EventTheme.primary.withOpacity(0.18),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                size: 14,
                color: widget.isSelected
                    ? EventTheme.primary
                    : EventTheme.textSecondary,
              ),
              const SizedBox(width: ThixPolicy.s7 ?? 7),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: widget.isSelected
                      ? FontWeight.w800
                      : FontWeight.w600,
                  color: widget.isSelected
                      ? EventTheme.textMain
                      : EventTheme.textSecondary,
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// CATEGORY CHIPS LIST
// ============================================================================
class CategoryChipsList extends StatelessWidget {
  final String? selectedSlug;
  final Function(String slug)? onCategorySelected;
  final bool includeAll;

  const CategoryChipsList({
    super.key,
    this.selectedSlug,
    this.onCategorySelected,
    this.includeAll = true,
  });

  /// Liste des slugs de catégories disponibles
  static const List<String> _categorySlugs = [
    'musique',
    'conference',
    'culture',
    'sport',
    'festival',
    'spectacle',
    'business',
    'exposition',
  ];

  /// Icône par catégorie
  static IconData _iconForSlug(String slug) {
    switch (slug.toLowerCase()) {
      case 'all':
        return Icons.auto_awesome_rounded;
      case 'musique':
      case 'concert':
        return Icons.music_note_rounded;
      case 'conference':
        return Icons.mic_rounded;
      case 'culture':
        return Icons.palette_rounded;
      case 'sport':
      case 'match':
        return Icons.sports_soccer_rounded;
      case 'festival':
        return Icons.celebration_rounded;
      case 'spectacle':
        return Icons.theater_comedy_rounded;
      case 'business':
        return Icons.business_center_rounded;
      case 'exposition':
        return Icons.museum_rounded;
      default:
        return Icons.event_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    
    // Construire la liste des slugs (avec "all" en premier si demandé)
    final slugs = <String>[
      if (includeAll) 'all',
      ..._categorySlugs,
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: ThixPolicy.s16,
        vertical: ThixPolicy.s4,
      ),
      physics: const BouncingScrollPhysics(),
      child: Semantics(
        label: l10n.t('category_chips_list_label'),
        child: Row(
          children: slugs.map((slug) {
            final label = l10n.t(_categoryKey(slug));
            final icon = _iconForSlug(slug);
            final isSelected = selectedSlug == slug;

            return CategoryChip(
              label: label,
              slug: slug,
              icon: icon,
              isSelected: isSelected,
              onTap: () {
                if (onCategorySelected != null) {
                  onCategorySelected!(slug);
                } else {
                  // Navigation par défaut vers la page de catégorie
                  if (slug == 'all') {
                    context.go('/thix-event');
                  } else {
                    context.push('/thix-event/category/$slug');
                  }
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }
}
