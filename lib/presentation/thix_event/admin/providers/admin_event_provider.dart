import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/models/event_model.dart';
import '../core/admin_constants.dart';
import '../services/admin_event_service.dart';
import 'admin_state.dart';
import 'admin_stats_model.dart';

final adminEventServiceProvider = Provider<AdminEventService>((ref) {
  return AdminEventService(Supabase.instance.client);
});

class AdminEventState {
  final AdminPaginatedState<Event> eventsState;
  final AdminStats stats;
  final bool statsLoading;
  final String searchQuery;
  final String categoryFilter;

  const AdminEventState({
    this.eventsState = const AdminPaginatedState<Event>(),
    this.stats = const AdminStats(totalEvents: 0, totalBookings: 0, totalRevenue: 0, waitingQueue: 0),
    this.statsLoading = false,
    this.searchQuery = '',
    this.categoryFilter = 'all',
  });

  AdminEventState copyWith({
    AdminPaginatedState<Event>? eventsState,
    AdminStats? stats,
    bool? statsLoading,
    String? searchQuery,
    String? categoryFilter,
  }) {
    return AdminEventState(
      eventsState: eventsState?? this.eventsState,
      stats: stats?? this.stats,
      statsLoading: statsLoading?? this.statsLoading,
      searchQuery: searchQuery?? this.searchQuery,
      categoryFilter: categoryFilter?? this.categoryFilter,
    );
  }
}

class AdminEventProvider extends StateNotifier<AdminEventState> {
  final AdminEventService _service;
  Timer? _debounce;
  final Map<String, List<Event>> _cache = {};
  DateTime? _lastCacheTime;

  AdminEventProvider(this._service) : super(const AdminEventState());

  bool _isCacheValid() {
    if (_lastCacheTime == null) return false;
    return DateTime.now().difference(_lastCacheTime!) < AdminConstants.cacheDuration;
  }

  Future<void> loadDashboardStats() async {
    if (state.statsLoading) return;
    state = state.copyWith(statsLoading: true);
    try {
      final stats = await _service.getDashboardStats();
      state = state.copyWith(stats: stats, statsLoading: false);
    } catch (e) {
      debugPrint('Stats error: $e');
      state = state.copyWith(statsLoading: false);
    }
  }

  Future<void> loadEvents({bool refresh = false}) async {
    if (refresh) {
      _cache.clear();
      state = state.copyWith(eventsState: const AdminPaginatedState<Event>());
    }
    if (state.eventsState.isLoading) return;

    state = state.copyWith(eventsState: state.eventsState.copyWith(status: AdminStatus.loading));

    try {
      final cacheKey = '${state.searchQuery}_${state.categoryFilter}_0';
      List<Event> events;
      if (!refresh && _cache.containsKey(cacheKey) && _isCacheValid()) {
        events = _cache[cacheKey]!;
      } else {
        events = await _service.getEventsPaginated(
          page: 0,
          pageSize: AdminConstants.eventsPageSize,
          search: state.searchQuery,
          category: state.categoryFilter == 'all'? null : state.categoryFilter,
        );
        _cache[cacheKey] = events;
        _lastCacheTime = DateTime.now();
      }

      state = state.copyWith(
        eventsState: AdminPaginatedState<Event>(
          items: events,
          status: events.isEmpty? AdminStatus.empty : AdminStatus.success,
          hasMore: events.length == AdminConstants.eventsPageSize,
          currentPage: 0,
        ),
      );
    } catch (e) {
      state = state.copyWith(eventsState: state.eventsState.copyWith(status: AdminStatus.error, error: e.toString()));
    }
  }

  Future<void> loadMoreEvents() async {
    final cur = state.eventsState;
    if (!cur.hasMore || cur.isLoadingMore || cur.isLoading) return;

    state = state.copyWith(eventsState: cur.copyWith(status: AdminStatus.loadingMore));

    try {
      final nextPage = cur.currentPage + 1;
      final newEvents = await _service.getEventsPaginated(
        page: nextPage,
        pageSize: AdminConstants.eventsPageSize,
        search: state.searchQuery,
        category: state.categoryFilter == 'all'? null : state.categoryFilter,
      );

      state = state.copyWith(
        eventsState: cur.copyWith(
          items: [...cur.items,...newEvents],
          status: AdminStatus.success,
          hasMore: newEvents.length == AdminConstants.eventsPageSize,
          currentPage: nextPage,
        ),
      );
    } catch (e) {
      state = state.copyWith(eventsState: cur.copyWith(status: AdminStatus.error, error: e.toString()));
    }
  }

  void searchEvents(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      state = state.copyWith(searchQuery: query.trim());
      loadEvents(refresh: true);
    });
  }

  void filterByCategory(String category) {
    state = state.copyWith(categoryFilter: category);
    loadEvents(refresh: true);
  }

  Future<bool> deleteEvent(String id) async {
    final old = List<Event>.from(state.eventsState.items);
    state = state.copyWith(eventsState: state.eventsState.copyWith(items: old.where((e) => e.id!= id).toList()));
    try {
      await _service.deleteEvent(id);
      _cache.clear();
      await loadDashboardStats();
      return true;
    } catch (_) {
      state = state.copyWith(eventsState: state.eventsState.copyWith(items: old));
      return false;
    }
  }

  Future<bool> toggleFeatured(String id, bool isFeatured) async {
    final idx = state.eventsState.items.indexWhere((e) => e.id == id);
    if (idx == -1) return false;
    final old = state.eventsState.items[idx];
    final updated = List<Event>.from(state.eventsState.items)..[idx] = old.copyWith(isFeatured: isFeatured);
    state = state.copyWith(eventsState: state.eventsState.copyWith(items: updated));
    try {
      await _service.updateEventField(id, {'is_featured': isFeatured});
      return true;
    } catch (_) {
      final rollback = List<Event>.from(state.eventsState.items)..[idx] = old;
      state = state.copyWith(eventsState: state.eventsState.copyWith(items: rollback));
      return false;
    }
  }

  // Getters compat anciens écrans
  AdminPaginatedState<Event> get eventsState => state.eventsState;
  AdminStats get stats => state.stats;
  bool get statsLoading => state.statsLoading;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}

final adminEventProvider = StateNotifierProvider<AdminEventProvider, AdminEventState>((ref) {
  final svc = ref.watch(adminEventServiceProvider);
  return AdminEventProvider(svc);
});
