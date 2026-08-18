// lib/presentation/thix_money/providers/loan_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/loan_model.dart';
import '../utils/constants.dart';

class LoanState {
  final List<LoanModel> items; final bool isLoading; final bool hasMore; final String? error;
  LoanState({required this.items, this.isLoading = false, this.hasMore = true, this.error});
  LoanState copyWith({List<LoanModel>? items, bool? isLoading, bool? hasMore, String? error}) => LoanState(items: items ?? this.items, isLoading: isLoading ?? this.isLoading, hasMore: hasMore ?? this.hasMore, error: error);
}

class LoanNotifier extends StateNotifier<LoanState> {
  LoanNotifier() : super(LoanState(items: [], isLoading: true));
  int _page = 0;
  final _db = Supabase.instance.client;

  Future<String> _getThixId() async {
    final res = await _db.from('profiles').select('thix_id').eq('id', _db.auth.currentUser!.id).single();
    return res['thix_id'] as String;
  }

  Future<void> load() async {
    try {
      final thixId = await _getThixId();
      final data = await _db.from('thix_loans').select().eq('thix_id', thixId).order('created_at', ascending: false).range(_page * ThixConstants.pageSize, (_page+1)*ThixConstants.pageSize -1);
      final items = (data as List).map((e) => LoanModel.fromJson(e)).toList();
      state = LoanState(items: [...state.items, ...items], hasMore: items.length == ThixConstants.pageSize);
      _page++;
    } catch (e) {
      state = LoanState(items: state.items, error: e.toString());
    }
  }

  Future<void> refresh() { _page=0; state = LoanState(items: [], isLoading: true); return load(); }
}

final loanProvider = StateNotifierProvider<LoanNotifier, LoanState>((ref) {
  final n = LoanNotifier(); n.load(); return n;
});
