import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/admin_state.dart';

class _ThixColors {
  static const bg = Color(0xFF050508);
  static const surface = Color(0xFF0C0C12);
  static const surfaceAlt = Color(0xFF111118);
  static const cardBorder = Color(0x14FFFFFF);
  static const primary = Color(0xFFFF0A54);
  static const textSecondary = Color(0x99FFFFFF);
  static const textMuted = Color(0x66FFFFFF);
}

final waitingQueueProvider = StateNotifierProvider<QueueNotifier, AdminPaginatedState<Map<String,dynamic>>>((ref) {
  return QueueNotifier();
});

class QueueNotifier extends StateNotifier<AdminPaginatedState<Map<String,dynamic>>> {
  RealtimeChannel? _ch;
  QueueNotifier() : super(const AdminPaginatedState()) {
    load(refresh: true);
    _subscribe();
  }

  void _subscribe() {
    _ch = Supabase.instance.client.channel('admin_waiting_queue')
      .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'event_waiting_queue', callback: (_) => load(refresh: true))
      .subscribe();
  }

  Future<void> load({bool refresh = false, bool loadMore = false}) async {
    if (refresh) state = state.copyWith(status: AdminStatus.loading, currentPage: 0, hasMore: true, items: []);
    if (loadMore) { if (!state.hasMore || state.isLoadingMore) return; state = state.copyWith(status: AdminStatus.loadingMore); }
    try {
      final page = refresh? 0 : state.currentPage + (loadMore? 1 : 0);
      final from = page * 50;
      final to = from + 49;
      final res = await Supabase.instance.client.from('event_waiting_queue').select('*, events(title)').order('created_at', ascending: true).range(from, to);
      final data = List<Map<String,dynamic>>.from(res as List);
      state = AdminPaginatedState(items: refresh? data : [...state.items,...data], status: data.isEmpty && refresh? AdminStatus.empty : AdminStatus.success, hasMore: data.length == 50, currentPage: page);
    } catch (e) { state = state.copyWith(status: AdminStatus.error, error: e.toString()); }
  }

  Future<void> notifyUser(String id) async {
    await Supabase.instance.client.from('event_waiting_queue').update({'status': 'notified', 'expires_at': DateTime.now().add(const Duration(minutes: 10)).toIso8601String()}).eq('id', id);
    await load(refresh: true);
  }

  @override void dispose() { if (_ch != null) Supabase.instance.client.removeChannel(_ch!); super.dispose(); }
}

class WaitingQueuePage extends ConsumerStatefulWidget {
  const WaitingQueuePage({super.key});
  @override ConsumerState<WaitingQueuePage> createState() => _WaitingQueuePageState();
}

class _WaitingQueuePageState extends ConsumerState<WaitingQueuePage> {
  final _scroll = ScrollController();
  @override void initState() { super.initState(); _scroll.addListener(() { if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300) ref.read(waitingQueueProvider.notifier).load(loadMore: true); }); }
  @override Widget build(BuildContext context) {
    final state = ref.watch(waitingQueueProvider);
    final notifier = ref.read(waitingQueueProvider.notifier);

    return Scaffold(
      backgroundColor: _ThixColors.bg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: AppBar(
              backgroundColor: _ThixColors.bg.withOpacity(0.85), elevation: 0,
              leading: IconButton(icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 18), onPressed: () => Navigator.of(context).pop()),
              title: Text('File d attente • Live (${state.items.length})', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
              actions: [IconButton(icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 18), onPressed: () => notifier.load(refresh: true))],
            ),
          ),
        ),
      ),
      body: Column(children: [
        Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: _ThixColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: _ThixColors.cardBorder)),
          child: Row(children: [Container(width: 6, height: 6, decoration: BoxDecoration(color: _ThixColors.primary, shape: BoxShape.circle, boxShadow: [BoxShadow(color: _ThixColors.primary.withOpacity(0.6), blurRadius: 6)])), const SizedBox(width: 8), const Expanded(child: Text('Temps reel actif • MAJ auto quand un user rejoint la queue', style: TextStyle(color: _ThixColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w600)))]),
        ),
        Expanded(
          child: switch (state.status) {
            AdminStatus.loading => const Center(child: CircularProgressIndicator(color: _ThixColors.primary, strokeWidth: 2)),
            AdminStatus.error => Center(child: Text(state.error?? 'Erreur', style: const TextStyle(color: _ThixColors.textMuted))),
            AdminStatus.empty => const Center(child: Text('Aucune attente', style: TextStyle(color: _ThixColors.textMuted))),
            _ => RefreshIndicator(
              color: Colors.white, backgroundColor: _ThixColors.surface,
              onRefresh: () async => notifier.load(refresh: true),
              child: ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.only(bottom: 100),
                itemCount: state.items.length + (state.hasMore? 1 : 0),
                itemBuilder: (ctx, i) {
                  if (i == state.items.length) return const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator(color: _ThixColors.primary, strokeWidth: 2)));
                  final item = state.items[i];
                  final title = item['events']?['title']?? 'Event';
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: _ThixColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: _ThixColors.cardBorder)),
                    child: Row(children: [
                      Container(width: 28, height: 28, decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), shape: BoxShape.circle, border: Border.all(color: _ThixColors.cardBorder)), child: Center(child: Text('${i+1}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)))),
                      const SizedBox(width: 10),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11)), const SizedBox(height: 2), Text('User: ${item['user_id'].toString().substring(0,8)}... • ${item['requested_quantity']} place(s) • ${item['status']}', style: const TextStyle(color: _ThixColors.textMuted, fontSize: 10))])),
                      const SizedBox(width: 8),
                      SizedBox(height: 28, child: ElevatedButton(onPressed: () => notifier.notifyUser(item['id']), style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black, elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))), child: const Text('Notifier', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800)))),
                    ]),
                  );
                },
              ),
            ),
          },
        ),
      ]),
    );
  }
}
