// lib/presentation/thix_event/admin/pages/bookings/waiting_queue_page.dart
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

// ── IMPORTS ABSOLUS SÉCURISÉS (Corrige l'erreur "ThixPolicy isn't defined") ──
import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import '../../../../providers/admin_state.dart';

// ============================================================================
// EVENT THEME (adapté depuis ThixPolicy — Admin Queue)
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
// LOGGING
// ============================================================================
class _QueueLogger {
  static const _tag = 'WaitingQueue';
  static void info(String m, [Map<String, dynamic>? d]) => _log('INFO', m, d);
  static void warn(String m, [Map<String, dynamic>? d]) => _log('WARN', m, d);
  static void error(String m, [Map<String, dynamic>? d]) => _log('ERROR', m, d);

  static void _log(String l, String m, Map<String, dynamic>? d) {
    if (!kDebugMode && l == 'INFO') return;
    final data = d != null
        ? ' ${d.entries.map((e) => '${e.key}=${e.value}').join(', ')}'
        : '';
    debugPrint('[$_tag] [$l] $m$data');
  }
}

// ============================================================================
// PROVIDER (LOGIQUE 100% PRÉSERVÉE)
// ============================================================================
final waitingQueueProvider =
    StateNotifierProvider<QueueNotifier, AdminPaginatedState<Map<String, dynamic>>>(
        (ref) {
  return QueueNotifier();
});

class QueueNotifier extends StateNotifier<AdminPaginatedState<Map<String, dynamic>>> {
  RealtimeChannel? _ch;

  QueueNotifier() : super(const AdminPaginatedState()) {
    load(refresh: true);
    _subscribe();
  }

  void _subscribe() {
    try {
      _ch = Supabase.instance.client
          .channel('admin_waiting_queue')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'event_waiting_queue',
            callback: (_) {
              _QueueLogger.info('Realtime event → refresh');
              load(refresh: true);
            },
          )
          .subscribe();
      _QueueLogger.info('Realtime subscription started');
    } catch (e) {
      _QueueLogger.error('Subscription failed', {'error': '$e'});
    }
  }

  Future<void> load({bool refresh = false, bool loadMore = false}) async {
    if (refresh) {
      state = state.copyWith(
        status: AdminStatus.loading,
        currentPage: 0,
        hasMore: true,
        items: [],
      );
    }
    if (loadMore) {
      if (!state.hasMore || state.isLoadingMore) return;
      state = state.copyWith(status: AdminStatus.loadingMore);
    }
    try {
      final page = refresh ? 0 : state.currentPage + (loadMore ? 1 : 0);
      final from = page * 50;
      final to = from + 49;
      final res = await Supabase.instance.client
          .from('event_waiting_queue')
          .select('*, events(title)')
          .order('created_at', ascending: true)
          .range(from, to);
      final data = List<Map<String, dynamic>>.from(res as List);
      state = AdminPaginatedState(
        items: refresh ? data : [...state.items, ...data],
        status: data.isEmpty && refresh ? AdminStatus.empty : AdminStatus.success,
        hasMore: data.length == 50,
        currentPage: page,
      );
      _QueueLogger.info('Queue loaded', {
        'page': page,
        'count': data.length,
        'total': state.items.length,
      });
    } catch (e) {
      _QueueLogger.error('Load failed', {'error': '$e'});
      state = state.copyWith(status: AdminStatus.error, error: e.toString());
    }
  }

  Future<void> notifyUser(String id) async {
    try {
      await Supabase.instance.client
          .from('event_waiting_queue')
          .update({
            'status': 'notified',
            'expires_at': DateTime.now()
                .add(const Duration(minutes: 10))
                .toIso8601String(),
          })
          .eq('id', id);
      _QueueLogger.info('User notified', {'id': id});
      await load(refresh: true);
    } catch (e) {
      _QueueLogger.error('Notify failed', {'id': id, 'error': '$e'});
    }
  }

  @override
  void dispose() {
    if (_ch != null) {
      try {
        Supabase.instance.client.removeChannel(_ch!);
      } catch (_) {}
    }
    _QueueLogger.info('QueueNotifier disposed');
    super.dispose();
  }
}

// ============================================================================
// PAGE
// ============================================================================
class WaitingQueuePage extends ConsumerStatefulWidget {
  const WaitingQueuePage({super.key});

  @override
  ConsumerState<WaitingQueuePage> createState() => _WaitingQueuePageState();
}

class _WaitingQueuePageState extends ConsumerState<WaitingQueuePage> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300) {
        ref.read(waitingQueueProvider.notifier).load(loadMore: true);
      }
    });
    _QueueLogger.info('WaitingQueuePage init');
  }

  @override
  void dispose() {
    _scroll.dispose();
    _QueueLogger.info('WaitingQueuePage disposed');
    super.dispose();
  }

  void _onNotify(Map<String, dynamic> item) {
    final l10n = AppLocalizations.of(context);
    final id = item['id']?.toString();
    if (id == null) return;

    HapticFeedback.mediumImpact();
    ref.read(waitingQueueProvider.notifier).notifyUser(id);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.t('admin_queue_notified')),
        backgroundColor: EventTheme.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(waitingQueueProvider);
    final notifier = ref.read(waitingQueueProvider.notifier);
    final mediaQuery = MediaQuery.of(context);
    final reduceMotion = mediaQuery.accessibleNavigation ||
        mediaQuery.disableAnimations;

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
                label: l10n.t('common_back'),
                child: IconButton(
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  onPressed: () => context.pop(),
                ),
              ),
              title: Text(
                l10n.tn('admin_queue_title', {
                  'count': state.items.length.toString(),
                }),
                style: ThixPolicy.labelStyle.copyWith(
                  color: EventTheme.textMain,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              actions: [
                Semantics(
                  button: true,
                  label: l10n.t('common_refresh'),
                  child: IconButton(
                    icon: const Icon(
                      Icons.refresh_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                    onPressed: () => notifier.load(refresh: true),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // ── BANNIERE REALTIME ──
          Container(
            margin: EdgeInsets.all(ThixPolicy.s12),
            padding: EdgeInsets.all(ThixPolicy.s10),
            decoration: BoxDecoration(
              color: EventTheme.surface,
              borderRadius: BorderRadius.circular(ThixPolicy.rSm),
              border: Border.all(color: EventTheme.border),
            ),
            child: Semantics(
              label: l10n.t('admin_queue_realtime_desc'),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: EventTheme.success,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: EventTheme.success.withOpacity(0.6),
                          blurRadius: reduceMotion ? 0 : 6,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: ThixPolicy.s8),
                  Expanded(
                    child: Text(
                      l10n.t('admin_queue_realtime_desc'),
                      style: ThixPolicy.microStyle.copyWith(
                        color: EventTheme.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── CONTENU ──
          Expanded(
            child: switch (state.status) {
              AdminStatus.loading => const Center(
                  child: CircularProgressIndicator(
                    color: EventTheme.primary,
                    strokeWidth: 2,
                  ),
                ),
              AdminStatus.error => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: EventTheme.danger,
                        size: 40,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        state.error ?? l10n.t('common_error'),
                        style: ThixPolicy.bodySmallStyle.copyWith(
                          color: EventTheme.textMuted,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () => notifier.load(refresh: true),
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: Text(l10n.t('common_retry')),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: EventTheme.surface,
                          foregroundColor: EventTheme.textMain,
                        ),
                      ),
                    ],
                  ),
                ),
              AdminStatus.empty => Center(
                  child: Text(
                    l10n.t('admin_queue_empty'),
                    style: ThixPolicy.bodyMediumStyle.copyWith(
                      color: EventTheme.textMuted,
                    ),
                  ),
                ),
              _ => RefreshIndicator(
                  color: Colors.white,
                  backgroundColor: EventTheme.surface,
                  onRefresh: () async => notifier.load(refresh: true),
                  child: ListView.builder(
                    controller: _scroll,
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: const EdgeInsets.only(bottom: 100),
                    itemCount: state.items.length + (state.hasMore ? 1 : 0),
                    itemBuilder: (ctx, i) {
                      if (i == state.items.length) {
                        return const Padding(
                          padding: EdgeInsets.all(20),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: EventTheme.primary,
                              strokeWidth: 2,
                            ),
                          ),
                        );
                      }
                      final item = state.items[i];
                      final title = item['events']?['title']?.toString() ??
                          l10n.t('admin_queue_event_fallback');
                      final userId = item['user_id']?.toString() ?? '';
                      final userIdShort = userId.length >= 8
                          ? '${userId.substring(0, 8)}...'
                          : userId;
                      final qty =
                          item['requested_quantity']?.toString() ?? '1';
                      final status =
                          item['status']?.toString() ?? 'waiting';

                      return Semantics(
                        label:
                            '${l10n.t('admin_queue_position')} ${i + 1}, $title, $qty ${l10n.t('admin_queue_places')}',
                        child: Container(
                          margin: EdgeInsets.symmetric(
                            horizontal: ThixPolicy.s12,
                            vertical: 4,
                          ),
                          padding: EdgeInsets.all(ThixPolicy.s12),
                          decoration: BoxDecoration(
                            color: EventTheme.surface,
                            borderRadius:
                                BorderRadius.circular(ThixPolicy.rMd),
                            border: Border.all(color: EventTheme.border),
                            boxShadow: ThixPolicy.shadowSoft(opacity: 0.15),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: EventTheme.primary.withOpacity(0.12),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: EventTheme.primary.withOpacity(0.25),
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    '${i + 1}',
                                    style: ThixPolicy.microStyle.copyWith(
                                      color: EventTheme.primary,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: ThixPolicy.s10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style:
                                          ThixPolicy.bodyMediumStyle.copyWith(
                                        color: EventTheme.textMain,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 11,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      l10n.tn('admin_queue_item_meta', {
                                        'userId': userIdShort,
                                        'qty': qty,
                                        'status': status,
                                      }),
                                      style:
                                          ThixPolicy.microStyle.copyWith(
                                        color: EventTheme.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(width: ThixPolicy.s8),
                              Semantics(
                                button: true,
                                label: l10n.t('admin_queue_notify'),
                                child: SizedBox(
                                  height: 28,
                                  child: ElevatedButton(
                                    onPressed: () => _onNotify(item),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: EventTheme.primary,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      padding: EdgeInsets.symmetric(
                                        horizontal: ThixPolicy.s12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          ThixPolicy.rMd,
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      l10n.t('admin_queue_notify'),
                                      style:
                                          ThixPolicy.microStyle.copyWith(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
            },
          ),
        ],
      ),
    );
  }
}
