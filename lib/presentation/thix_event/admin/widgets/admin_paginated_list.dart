// lib/presentation/thix_event/admin/widgets/admin_paginated_list.dart - FIXED BUILD VERT
import 'package:flutter/material.dart';
import '../providers/admin_state.dart';
import 'admin_state_widgets.dart'; // FIX: Import manquant qui causait AdminErrorWidget not defined

class AdminPaginatedList<T> extends StatefulWidget {
  final AdminPaginatedState<T> state;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onLoadMore;
  final Widget Function(BuildContext, T, int) itemBuilder;
  final Widget? header;

  const AdminPaginatedList({
    super.key,
    required this.state,
    required this.onRefresh,
    required this.onLoadMore,
    required this.itemBuilder,
    this.header,
  });

  @override
  State<AdminPaginatedList<T>> createState() => _AdminPaginatedListState<T>();
}

class _AdminPaginatedListState<T> extends State<AdminPaginatedList<T>> {
  final ScrollController _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
  }

  void _onScroll() {
    if (_controller.position.pixels >= _controller.position.maxScrollExtent * 0.8) {
      if (widget.state.hasMore && !widget.state.isLoadingMore) {
        widget.onLoadMore();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.state.status == AdminStatus.initial || widget.state.status == AdminStatus.loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    if (widget.state.status == AdminStatus.error) {
      return AdminErrorWidget(message: widget.state.error ?? 'Erreur', onRetry: widget.onRefresh);
    }

    if (widget.state.status == AdminStatus.empty || widget.state.items.isEmpty) {
      return AdminEmptyWidget(onRefresh: widget.onRefresh);
    }

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView.builder(
        controller: _controller,
        itemCount: widget.state.items.length + (widget.state.hasMore ? 1 : 0) + (widget.header != null ? 1 : 0),
        itemBuilder: (context, index) {
          if (widget.header != null && index == 0) return widget.header!;

          final adjustedIndex = widget.header != null ? index - 1 : index;

          if (adjustedIndex == widget.state.items.length) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: widget.state.isLoadingMore
                    ? const CircularProgressIndicator(strokeWidth: 2)
                    : Text('${widget.state.items.length} chargés • ${widget.state.hasMore ? "Scroll pour plus" : "Fin"}',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF7386A8))),
              ),
            );
          }

          return widget.itemBuilder(context, widget.state.items[adjustedIndex], adjustedIndex);
        },
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
