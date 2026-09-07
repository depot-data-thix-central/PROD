// lib/presentation/thix_event/admin/pages/events/event_list_admin_page.dart
//
// EventListAdminPage — Production Enterprise (i18n + Security + A11y + Logs)
//
import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

// ── IMPORTS ABSOLUS SÉCURISÉS ──
import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/presentation/thix_event/admin/core/admin_guards.dart';
import 'package:thix_id/presentation/thix_event/admin/providers/admin_event_provider.dart';
import 'package:thix_id/presentation/thix_event/admin/providers/admin_state.dart';

// ============================================================================
// EVENT THEME (Aligné sur ThixPolicy)
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
  static const Color danger = ThixPolicy.danger;
}

// ============================================================================
// LOGGING & SECURITY UTILS (XSS, UUID, Throttling)
// ============================================================================
class _EventListLogger {
  static const _tag = 'EventListAdmin';
  static void info(String m, [Map<String, dynamic>? d]) => _log('INFO', m, d);
  static void warn(String m, [Map<String, dynamic>? d]) => _log('WARN', m, d);
  static void error(String m, [Map<String, dynamic>? d]) => _log('ERROR', m, d);

  static void _log(String l, String m, Map<String, dynamic>? d) {
    if (!kDebugMode && l == 'INFO') return;
    final data = d != null ? ' ${d.entries.map((e) => '${e.key}=${e.value}').join(', ')}' : '';
    debugPrint('[$_tag] [$l] $m$data');
  }
}

class _SecurityUtils {
  // Strip HTML/Script tags to prevent basic XSS when rendering user inputs
  static String sanitizeInput(String input) {
    return input.replaceAll(RegExp(r'<[^>]*>|&[^;]+;'), '').trim();
  }

  // Validate UUID format before any backend deletion
  static bool isValidUUID(String uuid) {
    final regExp = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false,
    );
    return regExp.hasMatch(uuid);
  }
}

class _Debouncer {
  final int milliseconds;
  Timer? _timer;
  _Debouncer({required this.milliseconds});
  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: milliseconds), action);
  }
  void dispose() => _timer?.cancel();
}

// ============================================================================
// PAGE
// ============================================================================
class EventListAdminPage extends ConsumerStatefulWidget {
  const EventListAdminPage({super.key});
  @override
  ConsumerState<EventListAdminPage> createState() => _EventListAdminPageState();
}

class _EventListAdminPageState extends ConsumerState<EventListAdminPage> {
  final _searchCtrl = TextEditingController();
  final _scroll = ScrollController();
  final _debouncer = _Debouncer(milliseconds: 500); // Throttling for search
  String _cat = 'all';

  final List<String> _cats = [
    'all',
    'concert',
    'conference',
    'sport',
    'festival',
    'theatre'
  ];

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(adminEventProvider.notifier).loadEvents(refresh: true));
    
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300) {
        ref.read(adminEventProvider.notifier).loadMoreEvents();
      }
    });
    _EventListLogger.info('Init EventListAdminPage');
  }

  @override
  void dispose() {
    _debouncer.dispose();
    _searchCtrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    // Sanitization & Throttling
    final cleanQuery = _SecurityUtils.sanitizeInput(query);
    _debouncer.run(() {
      ref.read(adminEventProvider.notifier).searchEvents(cleanQuery);
      _EventListLogger.info('Search executed', {'query': cleanQuery});
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(adminEventProvider);
    final notifier = ref.read(adminEventProvider.notifier);
    final evState = state.eventsState;

    final mediaQuery = MediaQuery.of(context);
    final reduceMotion = mediaQuery.accessibleNavigation || mediaQuery.disableAnimations;

    return Scaffold(
      backgroundColor: EventTheme.bg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: reduceMotion ? 0 : 20,
              sigmaY: reduceMotion ? 0 : 20,
            ),
            child: AppBar(
              backgroundColor: EventTheme.bg.withOpacity(0.85),
              elevation: 0,
              leading: Semantics(
                button: true,
                label: l10n.t('common_back') ?? 'Retour',
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 18),
                  onPressed: () => context.pop(),
                ),
              ),
              title: Text(
                '${l10n.t('admin_events_title') ?? 'Evénements'} (${evState.items.length})',
                style: ThixPolicy.labelStyle.copyWith(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              actions: [
                Semantics(
                  button: true,
                  label: l10n.t('admin_events_create') ?? 'Créer',
                  child: IconButton(
                    icon: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      context.push('/thix-event/admin/events/create');
                    },
                  ),
                )
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // ── SEARCH & FILTER BAR ──
          Padding(
            padding: EdgeInsets.all(ThixPolicy.s12),
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    textField: true,
                    label: l10n.t('admin_events_search_hint') ?? 'Rechercher',
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: _onSearchChanged,
                      style: TextStyle(color: EventTheme.textMain, fontSize: 12),
                      decoration: InputDecoration(
                        hintText: l10n.t('admin_events_search_hint') ?? 'Rechercher par titre...',
                        hintStyle: TextStyle(color: EventTheme.textMuted, fontSize: 11),
                        prefixIcon: const Icon(Icons.search_rounded, size: 16, color: EventTheme.textMuted),
                        filled: true,
                        fillColor: EventTheme.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: EventTheme.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: EventTheme.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Colors.white24),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: ThixPolicy.s12,
                          vertical: ThixPolicy.s10,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: ThixPolicy.s8),
                Semantics(
                  button: true,
                  label: l10n.t('admin_events_filter') ?? 'Filtre catégorie',
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: ThixPolicy.s10),
                    decoration: BoxDecoration(
                      color: EventTheme.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: EventTheme.border),
                    ),
                    child: DropdownButton<String>(
                      value: _cat,
                      dropdownColor: EventTheme.surface,
                      underline: const SizedBox(),
                      style: TextStyle(color: EventTheme.textMain, fontSize: 11),
                      items: _cats.map((c) => DropdownMenuItem(value: c, child: Text(c.toUpperCase()))).toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        HapticFeedback.selectionClick();
                        setState(() => _cat = v);
                        notifier.filterByCategory(v);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // ── LIST BODY (Builder Pattern to avoid Dart 3 switch issues) ──
          Expanded(
            child: Builder(
              builder: (context) {
                if (evState.status == AdminStatus.loading) {
                  return const Center(
                    child: CircularProgressIndicator(color: EventTheme.primary, strokeWidth: 2),
                  );
                }

                if (evState.status == AdminStatus.error) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline_rounded, color: EventTheme.danger, size: 40),
                        SizedBox(height: ThixPolicy.s12),
                        Text(
                          evState.error ?? l10n.t('common_error') ?? 'Une erreur est survenue',
                          style: TextStyle(color: EventTheme.textMuted),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: ThixPolicy.s16),
                        ElevatedButton.icon(
                          onPressed: () => notifier.loadEvents(refresh: true),
                          icon: const Icon(Icons.refresh_rounded, size: 16),
                          label: Text(l10n.t('common_retry') ?? 'Réessayer'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: EventTheme.surface,
                            foregroundColor: EventTheme.textMain,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                if (evState.status == AdminStatus.empty) {
                  return Center(
                    child: Text(
                      l10n.t('admin_events_empty') ?? 'Aucun événement trouvé',
                      style: TextStyle(color: EventTheme.textMuted),
                    ),
                  );
                }

                // SUCCESS STATE
                return RefreshIndicator(
                  color: Colors.white,
                  backgroundColor: EventTheme.surface,
                  onRefresh: () async => notifier.loadEvents(refresh: true),
                  child: ListView.builder(
                    controller: _scroll,
                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                    padding: const EdgeInsets.only(bottom: 100),
                    itemCount: evState.items.length + (evState.hasMore ? 1 : 0),
                    itemBuilder: (ctx, i) {
                      if (i == evState.items.length) {
                        return const Padding(
                          padding: EdgeInsets.all(20),
                          child: Center(
                            child: CircularProgressIndicator(color: EventTheme.primary, strokeWidth: 2),
                          ),
                        );
                      }
                      return _EventTile(event: evState.items[i]);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// TILE WIDGET
// ============================================================================
class _EventTile extends ConsumerWidget {
  final dynamic event;
  
  const _EventTile({required this.event});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final notifier = ref.read(adminEventProvider.notifier);
    
    // Fallback parsing date
    DateTime dt;
    try {
      dt = event.startDate is String ? DateTime.parse(event.startDate) : event.startDate;
    } catch (_) {
      dt = DateTime.now();
    }
    
    final dateStr = DateFormat('dd MMM yyyy • HH:mm', locale).format(dt);
    final eventId = event.id?.toString() ?? '';
    final isFeatured = event.isFeatured == true;
    final title = _SecurityUtils.sanitizeInput(event.title?.toString() ?? 'Sans titre');

    return Semantics(
      label: 'Événement: $title, le $dateStr',
      child: Dismissible(
        key: Key(eventId),
        direction: DismissDirection.endToStart,
        confirmDismiss: (dir) async {
          final role = await AdminGuard.getCurrentRole();
          if (!AdminGuard.canDelete(role)) {
            if (!context.mounted) return false;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.t('admin_events_no_permission') ?? 'Permission refusée'),
                backgroundColor: EventTheme.danger,
              ),
            );
            return false;
          }

          if (!context.mounted) return false;
          HapticFeedback.heavyImpact();
          
          return await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              backgroundColor: EventTheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: EventTheme.border),
              ),
              title: Text(
                l10n.t('admin_events_delete_title') ?? 'Supprimer ?',
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800),
              ),
              content: Text(
                l10n.tn('admin_events_delete_desc', {'title': title}) ?? 'Voulez-vous supprimer $title ? Action irréversible.',
                style: const TextStyle(color: EventTheme.textSecondary, fontSize: 12),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(
                    l10n.t('common_cancel') ?? 'Annuler',
                    style: const TextStyle(color: EventTheme.textMuted),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(backgroundColor: EventTheme.danger),
                  child: Text(
                    l10n.t('common_delete') ?? 'Supprimer',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                  ),
                )
              ],
            ),
          ) ?? false;
        },
        onDismissed: (_) {
          if (!_SecurityUtils.isValidUUID(eventId)) {
            _EventListLogger.error('Tentative de suppression avec UUID invalide', {'id': eventId});
            return;
          }
          notifier.deleteEvent(eventId);
          _EventListLogger.info('Événement supprimé', {'id': eventId});
        },
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: EventTheme.danger,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.delete_rounded, color: Colors.white),
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: EventTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: EventTheme.border),
            boxShadow: ThixPolicy.shadowSoft(opacity: 0.15),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: event.imageUrl != null
                    ? Image.network(
                        event.imageUrl!,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _ph(),
                      )
                    : _ph(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: ThixPolicy.bodyMediumStyle.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        if (isFeatured)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: EventTheme.accent,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'STAR',
                              style: TextStyle(
                                color: EventTheme.bg,
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$dateStr • ${_SecurityUtils.sanitizeInput(event.city ?? event.location ?? '')}',
                      style: ThixPolicy.microStyle.copyWith(color: EventTheme.textMuted),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _badge('${event.price ?? 0} ${event.priceCurrency ?? 'FC'}'),
                        const SizedBox(width: 6),
                        _badge('${event.remainingTickets ?? 0}/${event.capacity ?? 0} rest.'),
                        const Spacer(),
                        Semantics(
                          label: 'Mettre en avant',
                          child: Switch.adaptive(
                            value: isFeatured,
                            activeColor: EventTheme.primary,
                            inactiveThumbColor: EventTheme.textMuted,
                            inactiveTrackColor: EventTheme.surfaceAlt,
                            onChanged: (v) {
                              HapticFeedback.lightImpact();
                              notifier.toggleFeatured(eventId, v);
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Semantics(
                button: true,
                label: l10n.t('common_edit') ?? 'Éditer',
                child: IconButton(
                  icon: const Icon(Icons.edit_rounded, size: 18, color: Colors.white),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    context.push('/thix-event/admin/events/create', extra: event);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ph() => Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: EventTheme.surfaceAlt,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: EventTheme.border),
        ),
        child: const Icon(Icons.image_rounded, color: EventTheme.textMuted, size: 18),
      );

  Widget _badge(String t) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: EventTheme.border),
        ),
        child: Text(
          t,
          style: ThixPolicy.microStyle.copyWith(
            color: EventTheme.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
}
