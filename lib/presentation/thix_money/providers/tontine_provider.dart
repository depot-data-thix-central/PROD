// lib/presentation/thix_money/providers/tontine_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/tontine_model.dart';
import '../utils/constants.dart';

class TontineState {
  final List<TontineModel> items; final bool isLoading; final bool hasMore; final String? error;
  TontineState({required this.items, this.isLoading = false, this.hasMore = true, this.error});
  TontineState copyWith({List<TontineModel>? items, bool? isLoading, bool? hasMore, String? error}) => TontineState(items: items ?? this.items, isLoading: isLoading ?? this.isLoading, hasMore: hasMore ?? this.hasMore, error: error);
}

class TontineNotifier extends StateNotifier<TontineState> {
  TontineNotifier() : super(TontineState(items: [], isLoading: true));
  int _page = 0;
  final _db = Supabase.instance.client;

  Future<String> _getThixId() async {
    final res = await _db.from('profiles').select('thix_id').eq('id', _db.auth.currentUser!.id).single();
    return res['thix_id'] as String;
  }

  // Pour millions d'users: pagination + filtre par thix_id membre via table de liaison thix_tontine_members
  Future<void> load() async {
    try {
      final thixId = await _getThixId();
      // Tontines où je suis membre
      final data = await _db.from('thix_tontines').select().eq('thix_id', thixId).order('created_at', ascending: false).range(_page * ThixConstants.pageSize, (_page+1)*ThixConstants.pageSize -1);
      final items = (data as List).map((e) => TontineModel.fromJson(e)).toList();
      state = TontineState(items: [...state.items, ...items], hasMore: items.length == ThixConstants.pageSize);
      _page++;
    } catch (e) {
      state = TontineState(items: state.items, error: e.toString());
    }
  }

  Future<void> refresh() { _page=0; state = TontineState(items: [], isLoading: true); return load(); }
}

final tontineProvider = StateNotifierProvider<TontineNotifier, TontineState>((ref) {
  final n = TontineNotifier(); n.load(); return n;
});
