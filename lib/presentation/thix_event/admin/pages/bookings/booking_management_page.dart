// lib/presentation/thix_event/admin/pages/bookings/booking_management_page.dart
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ── NOUVEAUX IMPORTS (alignement production) ─────────────────────────────────
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/admin_constants.dart';
import '../../core/theme/thix_design_policy.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/admin_state.dart';
import '../../services/admin_event_service.dart';

// ============================================================================
// EVENT THEME (adapté depuis ThixPolicy — Admin Bookings)
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
  static const Color warning = ThixPolicy.warning;
  static const Color danger = ThixPolicy.danger;
  static const Color info = Color(0xFF3B82F6);
}

// ============================================================================
// LOGGING
// ============================================================================
class _BookingsLogger {
  static const _tag = 'BookingsAdmin';
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
final adminBookingsProvider =
    StateNotifierProvider<BookingNotifier, AdminPaginatedState<Map<String, dynamic>>>(
        (ref) {
  return BookingNotifier(AdminEventService(Supabase.instance.client));
});

class BookingNotifier extends StateNotifier<AdminPaginatedState<Map<String, dynamic>>> {
  final AdminEventService _svc;
  String? filterEventId;

  BookingNotifier(this._svc) : super(const AdminPaginatedState());

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
      final data = await _svc.getBookingsPaginated(
        page: page,
        pageSize: 50,
        eventId: filterEventId,
      );
      state = AdminPaginatedState(
        items: refresh ? data : [...state.items, ...data],
        status: data.isEmpty && refresh ? AdminStatus.empty : AdminStatus.success,
        hasMore: data.length == 50,
        currentPage: page,
      );
      _BookingsLogger.info('Bookings loaded', {
        'page': page,
        'count': data.length,
        'total': state.items.length,
      });
    } catch (e) {
      _BookingsLogger.error('Load failed', {'error': '$e'});
      state = state.copyWith(status: AdminStatus.error, error: e.toString());
    }
  }
}

// ============================================================================
// PAGE
// ============================================================================
class BookingManagementPage extends ConsumerStatefulWidget {
  const BookingManagementPage({super.key});

  @override
  ConsumerState<BookingManagementPage> createState() =>
      _BookingManagementPageState();
}

class _BookingManagementPageState extends ConsumerState<BookingManagementPage> {
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() =>
        ref.read(adminBookingsProvider.notifier).load(refresh: true));
    _scrollCtrl.addListener(_onScroll);
    _BookingsLogger.info('BookingManagementPage init');
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >
        _scrollCtrl.position.maxScrollExtent - 300) {
      ref.read(adminBookingsProvider.notifier).load(loadMore: true);
    }
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _BookingsLogger.info('BookingManagementPage disposed');
    super.dispose();
  }

  // ────────────────────────────────────────────────────────────
  // STATUS HELPERS (logique exacte préservée)
  // ────────────────────────────────────────────────────────────
  Color _statusColor(String s) {
    switch (s.toLowerCase()) {
      case 'confirmed':
      case 'paid':
      case 'valide':
        return EventTheme.success;
      case 'used':
      case 'scanned':
        return EventTheme.textMuted;
      case 'cancelled':
        return EventTheme.primary;
      case 'postponed':
        return EventTheme.warning;
      default:
        return EventTheme.info;
    }
  }

  String _statusLabel(String s, AppLocalizations l10n) {
    switch (s.toLowerCase()) {
      case 'confirmed':
      case 'paid':
        return l10n.t('admin_bookings_status_valid');
      case 'used':
      case 'scanned':
        return l10n.t('admin_bookings_status_used');
      case 'cancelled':
        return l10n.t('admin_bookings_status_cancelled');
      case 'postponed':
        return l10n.t('admin_bookings_status_postponed');
      default:
        return l10n.t('admin_bookings_status_pending');
    }
  }

  // ────────────────────────────────────────────────────────────
  // MODAL DETAILS
  // ────────────────────────────────────────────────────────────
  void _showDetails(Map<String, dynamic> booking) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;

    final title = booking['events']?['title']?.toString() ??
        l10n.t('admin_bookings_unknown_event');
    final raw = booking['status']?.toString() ?? 'pending';
    final col = _statusColor(raw);
    final label = _statusLabel(raw, l10n);

    final dateStr = booking['booking_date'] != null
        ? DateFormat('dd MMM yyyy, HH:mm', locale)
            .format(DateTime.parse(booking['booking_date'].toString()))
        : l10n.t('admin_bookings_unknown_date');

    final id = booking['id']?.toString() ?? 'N/A';
    final qty = booking['ticket_quantity']?.toString() ?? '1';
    final cat = booking['ticket_category']?.toString() ??
        l10n.t('admin_seat_cat_standard');
    final price = booking['total_price']?.toString() ?? '0';
    final pin = booking['pin_code']?.toString() ?? 'N/A';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Semantics(
        dialog: true,
        child: Container(
          padding: const EdgeInsets.all(ThixPolicy.s20),
          decoration: BoxDecoration(
            color: EventTheme.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(ThixPolicy.r2Xl),
            ),
            border: const Border(top: BorderSide(color: EventTheme.border)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(ThixPolicy.s10),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.t('admin_bookings_details'),
                    style: ThixPolicy.titleStyle.copyWith(
                      color: EventTheme.textMain,
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: ThixPolicy.s8,
                      vertical: ThixPolicy.s4,
                    ),
                    decoration: BoxDecoration(
                      color: col.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(ThixPolicy.s8),
                      border: Border.all(color: col.withOpacity(0.3)),
                    ),
                    child: Text(
                      label,
                      style: ThixPolicy.microStyle.copyWith(
                        color: col,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _row(
                Icons.event_rounded,
                l10n.t('admin_bookings_event'),
                title,
              ),
              const Divider(color: EventTheme.border, height: 24),
              _row(
                Icons.receipt_long_rounded,
                l10n.t('admin_bookings_id'),
                id,
                mono: true,
              ),
              const Divider(color: EventTheme.border, height: 24),
              Row(
                children: [
                  Expanded(
                    child: _block(
                      l10n.t('admin_bookings_quantity'),
                      l10n.tn('admin_bookings_places', {'count': qty}),
                    ),
                  ),
                  const SizedBox(width: ThixPolicy.s12),
                  Expanded(
                    child: _block(l10n.t('admin_bookings_category'), cat),
                  ),
                ],
              ),
              const SizedBox(height: ThixPolicy.s12),
              Row(
                children: [
                  Expanded(
                    child: _block(
                      l10n.t('admin_bookings_amount'),
                      '$price FC',
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: ThixPolicy.s12),
                  Expanded(
                    child: _block(
                      l10n.t('admin_bookings_pin'),
                      pin,
                      mono: true,
                    ),
                  ),
                ],
              ),
              const Divider(color: EventTheme.border, height: 24),
              _row(
                Icons.access_time_rounded,
                l10n.t('admin_bookings_purchase_date'),
                dateStr,
              ),
              const SizedBox(height: 22),
              Semantics(
                button: true,
                label: l10n.t('admin_bookings_close'),
                child: SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: () => context.pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(ThixPolicy.r2Xl),
                      ),
                    ),
                    child: Text(
                      l10n.t('admin_bookings_close'),
                      style: ThixPolicy.labelStyle.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom),
            ],
          ),
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  // SUB-WIDGETS (logique préservée)
  // ────────────────────────────────────────────────────────────
  Widget _row(IconData icon, String label, String val, {bool mono = false}) =>
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: EventTheme.textMuted),
          const SizedBox(width: ThixPolicy.s10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: ThixPolicy.captionStyle.copyWith(
                    color: EventTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  val,
                  style: ThixPolicy.bodyMediumStyle.copyWith(
                    color: EventTheme.textMain,
                    fontWeight: FontWeight.w700,
                    fontFamily: mono ? 'monospace' : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      );

  Widget _block(String l, String v,
          {Color color = Colors.white, bool mono = false}) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l,
            style: ThixPolicy.captionStyle.copyWith(
              color: EventTheme.textMuted,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            v,
            style: ThixPolicy.bodyMediumStyle.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
              fontFamily: mono ? 'monospace' : null,
            ),
          ),
        ],
      );

  // ────────────────────────────────────────────────────────────
  // BUILD
  // ────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(adminBookingsProvider);
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
                l10n.t('admin_bookings_title'),
                style: ThixPolicy.labelStyle.copyWith(
                  color: EventTheme.textMain,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              actions: [
                Semantics(
                  button: true,
                  label: l10n.t('common_download'),
                  child: IconButton(
                    icon: const Icon(
                      Icons.download_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(l10n.t('admin_bookings_export')),
                          backgroundColor: EventTheme.primary,
                        ),
                      );
                      _BookingsLogger.info('Export requested');
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        color: Colors.white,
        backgroundColor: EventTheme.surface,
        onRefresh: () async =>
            ref.read(adminBookingsProvider.notifier).load(refresh: true),
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
                  const SizedBox(height: ThixPolicy.s12),
                  Text(
                    state.error ?? l10n.t('common_error'),
                    style: ThixPolicy.bodySmallStyle.copyWith(
                      color: EventTheme.textMuted,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: ThixPolicy.s16),
                  ElevatedButton.icon(
                    onPressed: () => ref
                        .read(adminBookingsProvider.notifier)
                        .load(refresh: true),
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
                l10n.t('admin_bookings_empty'),
                style: ThixPolicy.bodyMediumStyle.copyWith(
                  color: EventTheme.textMuted,
                ),
              ),
            ),
          _ => ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.only(top: 12, bottom: 100),
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
                final b = state.items[i];
                final title = b['events']?['title']?.toString() ??
                    l10n.t('admin_bookings_event');
                final raw = b['status']?.toString() ?? 'pending';
                final userId = b['user_id']?.toString() ?? '';
                final userIdShort = userId.length >= 8
                    ? '${userId.substring(0, 8)}...'
                    : userId;
                final qty = b['ticket_quantity']?.toString() ?? '1';
                final cat = b['ticket_category']?.toString() ??
                    l10n.t('admin_seat_cat_standard');
                final price = b['total_price']?.toString() ?? '0';

                return Semantics(
                  button: true,
                  label: '$title, ${_statusLabel(raw, l10n)}, $price FC',
                  child: Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: ThixPolicy.s16,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: EventTheme.surface,
                      borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                      border: Border.all(color: EventTheme.border),
                      boxShadow: ThixPolicy.shadowSoft(opacity: 0.15),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        _showDetails(b);
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(ThixPolicy.s14),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(ThixPolicy.s10),
                              decoration: BoxDecoration(
                                color: EventTheme.primary.withOpacity(0.12),
                                borderRadius:
                                    BorderRadius.circular(ThixPolicy.s10),
                                border: Border.all(
                                  color: EventTheme.primary.withOpacity(0.25),
                                ),
                              ),
                              child: const Icon(
                                Icons.confirmation_num_rounded,
                                size: 18,
                                color: EventTheme.primary,
                              ),
                            ),
                            const SizedBox(width: ThixPolicy.s12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style:
                                        ThixPolicy.bodyMediumStyle.copyWith(
                                      color: EventTheme.textMain,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '$userIdShort • $qty x $cat',
                                    style:
                                        ThixPolicy.captionStyle.copyWith(
                                      color: EventTheme.textMuted,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '$price FC',
                                    style:
                                        ThixPolicy.labelStyle.copyWith(
                                      color: EventTheme.textMain,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _statusColor(raw).withOpacity(0.12),
                                    borderRadius:
                                        BorderRadius.circular(ThixPolicy.s6),
                                    border: Border.all(
                                      color: _statusColor(raw).withOpacity(0.25),
                                    ),
                                  ),
                                  child: Text(
                                    _statusLabel(raw, l10n),
                                    style: ThixPolicy.microStyle.copyWith(
                                      color: _statusColor(raw),
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  color: EventTheme.textMuted,
                                  size: 18,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
        },
      ),
    );
  }
}
