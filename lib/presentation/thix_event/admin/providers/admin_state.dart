enum AdminStatus { initial, loading, loadingMore, success, empty, error }

class AdminPaginatedState<T> {
  final List<T> items;
  final AdminStatus status;
  final String? error;
  final bool hasMore;
  final int currentPage;

  const AdminPaginatedState({
    this.items = const [],
    this.status = AdminStatus.initial,
    this.error,
    this.hasMore = true,
    this.currentPage = 0,
  });

  AdminPaginatedState<T> copyWith({
    List<T>? items,
    AdminStatus? status,
    String? error,
    bool? hasMore,
    int? currentPage,
  }) {
    return AdminPaginatedState<T>(
      items: items ?? this.items,
      status: status ?? this.status,
      error: error,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
    );
  }

  bool get isInitial => status == AdminStatus.initial;
  bool get isLoading => status == AdminStatus.loading;
  bool get isLoadingMore => status == AdminStatus.loadingMore;
  bool get isSuccess => status == AdminStatus.success;
  bool get isEmptyState => status == AdminStatus.empty;
  bool get isError => status == AdminStatus.error;
  bool get isEmpty => items.isEmpty && (status == AdminStatus.success || status == AdminStatus.empty);
  bool get canLoadMore => hasMore && !isLoading && !isLoadingMore;
}
