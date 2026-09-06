// lib/presentation/thix_event/event_category_page.dart
//
// EventCategoryPage — Production Enterprise (i18n + Sécurité + A11y)
//
// Features :
// - Intégration AppLocalizations (8 langues)
// - Traduction dynamique des noms de catégories
// - Sanitization XSS sur tous les textes
// - Validation de category avant requête
// - Semantics complet pour a11y
// - Logging structuré (_CategoryLogger)
// - Throttling anti-spam (500ms)
// - Utilisation EventTheme + ThixPolicy
// - Gestion erreurs robuste avec retry
// - Pagination infinie optimisée
import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/thix_design_policy.dart';
import '../../l10n/app_localizations.dart';
import '../../models/event_model.dart';
import '../../providers/event_provider.dart';

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
}

// ============================================================================
// CONSTANTS
// ============================================================================
const Duration _kActionThrottle = Duration(milliseconds: 500);
const Duration _kOperationTimeout = Duration(seconds: 15);
const int _kPageSize = 20;

// ============================================================================
// LOGGING
// ============================================================================
class _CategoryLogger {
  static const _tag = 'EventCategory';
  static void info(String m, [Map<String, dynamic>? d]) => _log('INFO', m, d);
  static void warn(String m, [Map<String, dynamic>? d]) => _log('WARN', m, d);
  static void error(String m, [Map<String, dynamic>? d]) => _log('ERROR', m, d);

  static void _log(String l, String m, Map<String, dynamic>? d) {
    if (!kDebugMode && l == 'INFO') return;
    final data = d != null ? ' ${d.entries.map((e) => '${e.key}=${e.value}').join(', ')}' : '';
    debugPrint('[$_tag] [$l] $m$data');
  }
}

// ============================================================================
// VALIDATORS & SANITIZERS
// ============================================================================
class _Validators {
  _Validators._();
  
  static final _allowedCategories = {
    'all', 'musique', 'concert', 'festival', 'business',
    'conference', 'culture', 'sport', 'spectacle',
  };
  
  static bool isValidCategory(String? cat) =>
      cat != null && _allowedCategories.contains(cat.toLowerCase());
}

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
      return 'category_music';
    case 'festival':
      return 'category_festival';
    case 'business':
      return 'category_business';
    case 'conference':
      return 'category_conference';
    case 'culture':
      return 'category_culture';
    case 'sport':
      return 'category_sport';
    case 'spectacle':
      return 'category_spectacle';
    default:
      return 'category_other';
  }
}

// ============================================================================
// PAGE
// ============================================================================
class EventCategoryPage extends ConsumerStatefulWidget {
  final String category;
  
  const EventCategoryPage({super.key, required this.category});

  @override
  ConsumerState<EventCategoryPage> createState() => _EventCategoryPageState();
}

class _EventCategoryPageState extends ConsumerState<EventCategoryPage> {
  final ScrollController _scroll = ScrollController();
  List<Event> _events = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 0;
  String? _error;
  DateTime? _lastAction;

  @override
  void initState() {
    super.initState();
    
    // Validation category
    if (!_Validators.isValidCategory(widget.category)) {
      _CategoryLogger.error('Invalid category', {'category': widget.category});
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.pop();
      });
      return;
    }
    
    _scroll.addListener(_onScroll);
    _load();
    _CategoryLogger.info('EventCategoryPage init', {
      'category': widget.category,
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _CategoryLogger.info('EventCategoryPage disposed');
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300 &&
        !_loading &&
        !_loadingMore &&
        _hasMore) {
      _loadMore();
    }
  }

  bool _throttle() {
    final now = DateTime.now();
    if (_lastAction != null &&
        now.difference(_lastAction!) < _kActionThrottle) {
      return false;
    }
    _lastAction = now;
    return true;
  }

  Future<void> _load({bool refresh = false}) async {
    if (refresh) {
      _page = 0;
      _hasMore = true;
    }
    
    setState(() {
      _loading = true;
      _error = null;
    });
    
    try {
      final svc = ref.read(eventServiceProvider);
      final res = await svc
          .getEvents(
            category: widget.category,
            page: 0,
            limit: _kPageSize,
          )
          .timeout(_kOperationTimeout);
      
      if (!mounted) return;
      
      setState(() {
        _events = res;
        _loading = false;
        _hasMore = res.length >= _kPageSize;
        _page = 0;
      });
      
      _CategoryLogger.info('Events loaded', {
        'count': res.length,
        'category': widget.category,
      });
    } on TimeoutException {
      _CategoryLogger.error('Load timeout');
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        setState(() {
          _loading = false;
          _error = l10n.t('error_timeout');
        });
      }
    } catch (e, stack) {
      _CategoryLogger.error('Load failed', {
        'error': '$e',
        'stack': stack.toString(),
      });
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        setState(() {
          _loading = false;
          _error = l10n.t('category_connection_error');
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    
    setState(() => _loadingMore = true);
    
    try {
      final svc = ref.read(eventServiceProvider);
      final res = await svc
          .getEvents(
            category: widget.category,
            page: _page + 1,
            limit: _kPageSize,
          )
          .timeout(_kOperationTimeout);
      
      if (!mounted) return;
      
      setState(() {
        _page++;
        _events = [..._events, ...res];
        _hasMore = res.length >= _kPageSize;
        _loadingMore = false;
      });
      
      _CategoryLogger.info('More events loaded', {
        'count': res.length,
        'total': _events.length,
      });
    } on TimeoutException {
      _CategoryLogger.warn('LoadMore timeout');
      if (mounted) setState(() => _loadingMore = false);
    } catch (e) {
      _CategoryLogger.warn('LoadMore failed', {'error': '$e'});
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _navigateToEvent(Event event) {
    if (!_throttle()) {
      _CategoryLogger.warn('Navigation throttled');
      return;
    }
    
    HapticFeedback.selectionClick();
    _CategoryLogger.info('Navigate to event', {'id': event.id});
    context.push('/thix-event/event/${event.id}');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final categoryName = l10n.t(_categoryKey(widget.category));
    
    return Scaffold(
      backgroundColor: EventTheme.bg,
      appBar: _appBar(l10n, categoryName),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(color: EventTheme.primary),
            )
          : _error != null
              ? _errorState(l10n)
              : _events.isEmpty
                  ? _emptyState(l10n)
                  : RefreshIndicator(
                      color: EventTheme.primary,
                      backgroundColor: EventTheme.surface,
                      onRefresh: () => _load(refresh: true),
                      child: CustomScrollView(
                        controller: _scroll,
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        slivers: [
                          // Header avec compte
                          SliverToBoxAdapter(
                            child: _buildHeader(l10n, categoryName),
                          ),
                          
                          // Grille d'événements
                          SliverPadding(
                            padding: const EdgeInsets.all(ThixPolicy.s16),
                            sliver: SliverGrid(
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisSpacing: 14,
                                crossAxisSpacing: 14,
                                childAspectRatio: 0.68,
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (_, i) => _card(l10n, _events[i]),
                                childCount: _events.length,
                              ),
                            ),
                          ),
                          
                          // Loader pagination
                          if (_loadingMore)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: ThixPolicy.s24,
                                ),
                                child: Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: EventTheme.primary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          
                          const SliverToBoxAdapter(
                            child: SizedBox(height: 100),
                          ),
                        ],
                      ),
                    ),
    );
  }

  PreferredSizeWidget _appBar(AppLocalizations l10n, String categoryName) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(52),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: AppBar(
            backgroundColor: EventTheme.bg.withOpacity(0.85),
            elevation: 0,
            leading: Padding(
              padding: const EdgeInsets.all(ThixPolicy.s8),
              child: Semantics(
                button: true,
                label: l10n.t('common_back'),
                child: InkWell(
                  onTap: () => context.pop(),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      shape: BoxShape.circle,
                      border: Border.all(color: EventTheme.border),
                    ),
                    child: const Icon(
                      Icons.arrow_back_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ),
            title: Text(
              categoryName,
              style: ThixPolicy.titleStyle.copyWith(
                color: EventTheme.textMain,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
            centerTitle: true,
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(AppLocalizations l10n, String categoryName) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        ThixPolicy.s16,
        ThixPolicy.s12,
        ThixPolicy.s16,
        0,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(ThixPolicy.s8),
            decoration: BoxDecoration(
              color: EventTheme.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(ThixPolicy.s8),
            ),
            child: Icon(
              Icons.local_activity_rounded,
              color: EventTheme.primary,
              size: 18,
            ),
          ),
          const SizedBox(width: ThixPolicy.s10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  categoryName,
                  style: ThixPolicy.titleStyle.copyWith(
                    color: EventTheme.textMain,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  l10n.plural('category_events_count', _events.length),
                  style: ThixPolicy.captionStyle.copyWith(
                    color: EventTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(AppLocalizations l10n, Event event) {
    final safeTitle = _Sanitizer.text(event.title, maxLength: 80);
    final safeImageUrl = _Sanitizer.text(event.imageUrl, maxLength: 500);
    
    return Semantics(
      button: true,
      label: '$safeTitle, ${event.formattedPrice}',
      child: GestureDetector(
        onTap: () => _navigateToEvent(event),
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
                            errorBuilder: (_, __, ___) => Container(
                              color: EventTheme.surfaceAlt,
                              child: Icon(
                                Icons.image_not_supported_rounded,
                                color: EventTheme.textMuted,
                              ),
                            ),
                          )
                        : Container(
                            color: EventTheme.surfaceAlt,
                            child: Icon(
                              Icons.confirmation_num_rounded,
                              color: EventTheme.textMuted,
                              size: 40,
                            ),
                          ),
                  ),
                  
                  // Badge prix
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(ThixPolicy.s12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.12),
                        ),
                      ),
                      child: Text(
                        event.formattedPrice,
                        style: ThixPolicy.microStyle.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(ThixPolicy.s12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        safeTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: ThixPolicy.bodySmallStyle.copyWith(
                          color: EventTheme.textMain,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Container(
                            height: 26,
                            width: 26,
                            decoration: BoxDecoration(
                              color: EventTheme.primary.withOpacity(0.15),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: EventTheme.primary.withOpacity(0.3),
                              ),
                            ),
                            child: Icon(
                              Icons.arrow_outward_rounded,
                              color: EventTheme.primary,
                              size: 12,
                            ),
                          ),
                          const SizedBox(width: ThixPolicy.s6),
                          Expanded(
                            child: Text(
                              l10n.t('category_book'),
                              style: ThixPolicy.captionStyle.copyWith(
                                color: EventTheme.textSecondary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _errorState(AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(ThixPolicy.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(ThixPolicy.s16),
              decoration: BoxDecoration(
                color: ThixPolicy.danger.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.wifi_off_rounded,
                color: ThixPolicy.danger,
                size: 32,
              ),
            ),
            const SizedBox(height: ThixPolicy.s14),
            Text(
              _error ?? l10n.t('error_generic'),
              textAlign: TextAlign.center,
              style: ThixPolicy.bodySmallStyle.copyWith(
                color: EventTheme.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: ThixPolicy.s16),
            Semantics(
              button: true,
              label: l10n.t('common_retry'),
              child: ElevatedButton(
                onPressed: () => _load(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(ThixPolicy.rLg),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: ThixPolicy.s24,
                    vertical: ThixPolicy.s12,
                  ),
                ),
                child: Text(
                  l10n.t('common_retry'),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(ThixPolicy.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(ThixPolicy.s20),
              decoration: BoxDecoration(
                color: EventTheme.surface,
                shape: BoxShape.circle,
                border: Border.all(color: EventTheme.border),
              ),
              child: Icon(
                Icons.local_activity_outlined,
                size: 40,
                color: EventTheme.textMuted,
              ),
            ),
            const SizedBox(height: ThixPolicy.s16),
            Text(
              l10n.t('category_no_events'),
              style: ThixPolicy.titleStyle.copyWith(
                color: EventTheme.textMain,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: ThixPolicy.s6),
            Text(
              l10n.t('category_no_events_desc'),
              textAlign: TextAlign.center,
              style: ThixPolicy.bodySmallStyle.copyWith(
                color: EventTheme.textMuted,
                height: 1.4,
              ),
            ),
            const SizedBox(height: ThixPolicy.s20),
            Semantics(
              button: true,
              label: l10n.t('common_back'),
              child: OutlinedButton(
                onPressed: () => context.pop(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: EventTheme.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(ThixPolicy.rLg),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: ThixPolicy.s24,
                    vertical: ThixPolicy.s12,
                  ),
                ),
                child: Text(
                  l10n.t('common_back'),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
