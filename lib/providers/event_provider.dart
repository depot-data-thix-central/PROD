import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/event_service.dart';
import '../models/event_model.dart';
import '../models/event_booking.dart';

// Service
final eventServiceProvider = Provider<EventService>((ref) {
  return EventService(Supabase.instance.client);
});

// Filters - plus de hardcode dans le provider
final eventCategoryProvider = StateProvider<String>((ref) => 'all');
final eventDateFilterProvider = StateProvider<String>((ref) => 'all');
final eventCityProvider = StateProvider<String>((ref) => 'all');
final eventSearchProvider = StateProvider<String>((ref) => '');

// Pagination state
class EventListState {
  final List<Event> items;
  final bool hasMore;
  final int page;
  const EventListState({this.items = const [], this.hasMore = true, this.page = 0});
}

final eventListProvider = AsyncNotifierProvider<EventListNotifier, EventListState>(() => EventListNotifier());

class EventListNotifier extends AsyncNotifier<EventListState> {
  static const _limit = 20;

  @override
  Future<EventListState> build() async {
    final category = ref.watch(eventCategoryProvider);
    final dateFilter = ref.watch(eventDateFilterProvider);
    final city = ref.watch(eventCityProvider);
    final q = ref.watch(eventSearchProvider);

    ref.watch(eventCategoryProvider);
    // fetch page 0
    final events = await _fetchPage(0, category: category, dateFilter: dateFilter, city: city, query: q);
    return EventListState(items: events, hasMore: events.length >= _limit, page: 0);
  }

  Future<List<Event>> _fetchPage(int page, {String? category, String? dateFilter, String? city, String? query}) async {
    final svc = ref.read(eventServiceProvider);
    if (query!= null && query.isNotEmpty) {
      return svc.searchEvents(query);
    }
    return svc.getEvents(
      category: category!= 'all'? category : null,
      dateFilter: dateFilter?? 'all',
      city: city!= 'all'? city : null,
      page: page,
      limit: _limit,
    );
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current== null ||!current.hasMore || state.isLoading) return;
    final nextPage = current.page + 1;
    final category = ref.read(eventCategoryProvider);
    final dateFilter = ref.read(eventDateFilterProvider);
    final city = ref.read(eventCityProvider);
    final q = ref.read(eventSearchProvider);
    final more = await _fetchPage(nextPage, category: category, dateFilter: dateFilter, city: city, query: q);
    state = AsyncData(EventListState(
      items: [...current.items,...more],
      hasMore: more.length >= _limit,
      page: nextPage,
    ));
  }

  Future<void> refreshList() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final category = ref.read(eventCategoryProvider);
      final dateFilter = ref.read(eventDateFilterProvider);
      final city = ref.read(eventCityProvider);
      final q = ref.read(eventSearchProvider);
      final events = await _fetchPage(0, category: category, dateFilter: dateFilter, city: city, query: q);
      return EventListState(items: events, hasMore: events.length >= _limit, page: 0);
    });
  }

  Future<void> toggleLike(String eventId) async {
    final svc = ref.read(eventServiceProvider);
    final current = state.valueOrNull;
    if (current== null) return;
    final idx = current.items.indexWhere((e) => e.id == eventId);
    if (idx== -1) return;
    final ev = current.items[idx];
    final newItems = [...current.items];
    newItems[idx] = ev.copyWith(isLiked:!ev.isLiked);
    state = AsyncData(current.copyWith(items: newItems));
    try {
      if (ev.isLiked) { await svc.unlikeEvent(eventId); } else { await svc.likeEvent(eventId); }
      ref.invalidate(favoriteEventsProvider);
    } catch (_) {
      // rollback
      state = AsyncData(current);
    }
  }
}

extension on EventListState {
  EventListState copyWith({List<Event>? items, bool? hasMore, int? page}) =>
      EventListState(items: items?? this.items, hasMore: hasMore?? this.hasMore, page: page?? this.page);
}

// Featured
final featuredEventsProvider = AsyncNotifierProvider<FeaturedEventsNotifier, List<Event>>(() => FeaturedEventsNotifier());
class FeaturedEventsNotifier extends AsyncNotifier<List<Event>> {
  DateTime? _last;
  @override Future<List<Event>> build() async {
    if (_last!= null && DateTime.now().difference(_last!).inMinutes < 5 && state.hasValue) return state.value!;
    final svc = ref.read(eventServiceProvider);
    final data = await svc.getFeaturedEvents();
    _last = DateTime.now();
    return data;
  }
  Future<void> refresh() async { _last = null; state = const AsyncLoading(); state = await AsyncValue.guard(() => ref.read(eventServiceProvider).getFeaturedEvents()); }
}

// Favorites
final favoriteEventsProvider = AsyncNotifierProvider<FavoriteEventsNotifier, List<Event>>(() => FavoriteEventsNotifier());
class FavoriteEventsNotifier extends AsyncNotifier<List<Event>> {
  @override Future<List<Event>> build() => ref.read(eventServiceProvider).getFavoriteEvents();
  Future<void> refresh() async => state = await AsyncValue.guard(() => ref.read(eventServiceProvider).getFavoriteEvents());
}

// My tickets
final myTicketsProvider = AsyncNotifierProvider<MyTicketsNotifier, List<EventBooking>>(() => MyTicketsNotifier());
class MyTicketsNotifier extends AsyncNotifier<List<EventBooking>> {
  @override Future<List<EventBooking>> build() => ref.read(eventServiceProvider).getMyTickets();
  Future<void> refresh() async => state = await AsyncValue.guard(() => ref.read(eventServiceProvider).getMyTickets());
}

// Derived providers scalable
final upcomingEventsProvider = Provider<List<Event>>((ref) {
  final all = ref.watch(eventListProvider).valueOrNull?.items?? [];
  return all.where((e) => e.isUpcoming &&!e.isPastEvent).take(20).toList();
});

final recommendedEventsProvider = Provider<List<Event>>((ref) {
  final all = ref.watch(eventListProvider).valueOrNull?.items?? [];
  return all.where((e) => e.isFeatured || e.isUpcoming).take(10).toList();
});

final bookingProvider = Provider<BookingService>((ref) => BookingService(ref));
class BookingService {
  final Ref ref;
  BookingService(this.ref);
  Future<EventBooking?> book({required String eventId, required int qty, required double total, String? payment}) async {
    final b = await ref.read(eventServiceProvider).bookTicket(eventId: eventId, quantity: qty, totalPrice: total, paymentMethod: payment);
    if (b!= null) { ref.invalidate(myTicketsProvider); ref.invalidate(eventListProvider); }
    return b;
  }
  Future<String?> uploadImage(Uint8List bytes, String name) => ref.read(eventServiceProvider).uploadImage(bytes, name);
}
