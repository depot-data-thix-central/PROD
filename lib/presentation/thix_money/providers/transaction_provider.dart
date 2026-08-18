// lib/presentation/thix_money/providers/transaction_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/transaction_model.dart';
import '../services/wallet_service.dart';
import '../utils/constants.dart';

class TransactionState {
  final List<TransactionModel> items;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? error;
  TransactionState({required this.items, this.isLoading = false, this.isLoadingMore = false, this.hasMore = true, this.error});
  TransactionState copyWith({List<TransactionModel>? items, bool? isLoading, bool? isLoadingMore, bool? hasMore, String? error}) {
    return TransactionState(items: items ?? this.items, isLoading: isLoading ?? this.isLoading, isLoadingMore: isLoadingMore ?? this.isLoadingMore, hasMore: hasMore ?? this.hasMore, error: error);
  }
}

class TransactionNotifier extends StateNotifier<TransactionState> {
  TransactionNotifier() : super(TransactionState(items: [], isLoading: true));
  int _page = 0;
  final _db = Supabase.instance.client;

  Future<String> _getThixId() async {
    final uid = _db.auth.currentUser!.id;
    final res = await _db.from('profiles').select('thix_id').eq('id', uid).single();
    return res['thix_id'] as String;
  }

  Future<void> loadInitial() async {
    _page = 0;
    state = TransactionState(items: [], isLoading: true, hasMore: true);
    try {
      final thixId = await _getThixId();
      final data = await _db.from('thix_transactions').select().eq('thix_id', thixId).order('created_at', ascending: false).range(0, ThixConstants.pageSize - 1);
      final items = (data as List).map((e) => TransactionModel.fromJson(e)).toList();
      state = TransactionState(items: items, hasMore: items.length == ThixConstants.pageSize);
      _page = 1;
    } catch (e) {
      state = TransactionState(items: [], error: e.toString());
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoadingMore) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final thixId = await _getThixId();
      final from = _page * ThixConstants.pageSize;
      final to = from + ThixConstants.pageSize - 1;
      final data = await _db.from('thix_transactions').select().eq('thix_id', thixId).order('created_at', ascending: false).range(from, to);
      final newItems = (data as List).map((e) => TransactionModel.fromJson(e)).toList();
      state = state.copyWith(items: [...state.items, ...newItems], hasMore: newItems.length == ThixConstants.pageSize, isLoadingMore: false);
      _page++;
    } catch (e) {
      state = state.copyWith(isLoadingMore: false, error: e.toString());
    }
  }

  Future<void> refresh() => loadInitial();
}

final transactionProvider = StateNotifierProvider<TransactionNotifier, TransactionState>((ref) {
  final notifier = TransactionNotifier();
  notifier.loadInitial();
  return notifier;
});
