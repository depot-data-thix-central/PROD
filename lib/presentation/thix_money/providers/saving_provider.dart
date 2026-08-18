// lib/presentation/thix_money/providers/saving_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/saving_model.dart';
import '../utils/constants.dart';

class SavingState {
  final List<SavingModel> items; final bool isLoading; final bool hasMore; final String? error;
  SavingState({required this.items, this.isLoading = false, this.hasMore = true, this.error});
  SavingState copyWith({List<SavingModel>? items, bool? isLoading, bool? hasMore, String? error}) => SavingState(items: items ?? this.items, isLoading: isLoading ?? this.isLoading, hasMore: hasMore ?? this.hasMore, error: error);
}

class SavingNotifier extends StateNotifier<SavingState> {
  SavingNotifier() : super(SavingState(items: [], isLoading: true));
  int _page = 0;
  final _db = Supabase.instance.client;

  Future<String> _getThixId() async {
    final res = await _db.from('profiles').select('thix_id').eq('id', _db.auth.currentUser!.id).single();
    return res['thix_id'] as String;
  }

  Future<void> load() async {
    try {
      final thixId = await _getThixId();
      final from = _page * ThixConstants.pageSize;
      final to = from + ThixConstants.pageSize -1;
      final data = await _db.from('thix_savings').select().eq('thix_id', thixId).order('created_at', ascending: false).range(from, to);
      final items = (data as List).map((e) => SavingModel.fromJson(e)).toList();
      state = SavingState(items: [...state.items, ...items], hasMore: items.length == ThixConstants.pageSize);
      _page++;
    } catch (e) {
      state = SavingState(items: state.items, error: e.toString());
    }
  }

  Future<void> refresh() { _page = 0; state = SavingState(items: [], isLoading: true); return load(); }
}

final savingProvider = StateNotifierProvider<SavingNotifier, SavingState>((ref) {
  final n = SavingNotifier(); n.load(); return n;
});
