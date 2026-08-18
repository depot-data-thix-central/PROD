// lib/presentation/thix_weeding/pages/guest/livre_or_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../data/repositories/wedding_repository_impl.dart';

part 'livre_or_page.g.dart';

class GuestbookEntry {
  final String id;
  final String guestName;
  final String message;
  final DateTime date;
  GuestbookEntry({required this.id, required this.guestName, required this.message, required this.date});
  factory GuestbookEntry.fromJson(Map<String, dynamic> json) => GuestbookEntry(id: json['id'] as String, guestName: json['guest_name'] as String, message: json['message'] as String, date: DateTime.parse(json['created_at'] as String));
}

@riverpod
Future<List<GuestbookEntry>> guestbookEntries(GuestbookEntriesRef ref, String weddingId) async {
  // En prod: via remote datasource
  await Future.delayed(const Duration(milliseconds: 400));
  return [
    GuestbookEntry(id: '1', guestName: 'Maman Sarah', message: 'Tellement émue, félicitations mes amours!', date: DateTime.now().subtract(const Duration(hours: 2))),
    GuestbookEntry(id: '2', guestName: 'David Junior', message: 'Longue vie à vous deux!', date: DateTime.now().subtract(const Duration(hours: 5))),
  ];
}

@riverpod
class GuestbookPoster extends _$GuestbookPoster {
  @override
  FutureOr<void> build() {}
  Future<bool> post(String weddingId, String name, String message) async {
    state = const AsyncLoading();
    final repo = ref.read(weddingRepositoryProvider);
    state = await AsyncValue.guard(() => repo.submitLivreOr(weddingId, name, message));
    return !state.hasError;
  }
}

class LivreOrPage extends ConsumerStatefulWidget {
  final String weddingId;
  const LivreOrPage({super.key, required this.weddingId});
  @override
  ConsumerState<LivreOrPage> createState() => _LivreOrPageState();
}

class _LivreOrPageState extends ConsumerState<LivreOrPage> {
  final _nameCtrl = TextEditingController();
  final _msgCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final name = _nameCtrl.text.trim();
    final msg = _msgCtrl.text.trim();
    if (name.length < 2 || msg.length < 3) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nom min 2, message min 3 caractères')));
      return;
    }
    final ok = await ref.read(guestbookPosterProvider.notifier).post(widget.weddingId, name, msg);
    if (!mounted) return;
    if (ok) {
      _msgCtrl.clear();
      ref.invalidate(guestbookEntriesProvider(widget.weddingId));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Message publié!')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final entriesAsync = ref.watch(guestbookEntriesProvider(widget.weddingId));
    final postState = ref.watch(guestbookPosterProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Livre d’or'), leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () { if (context.mounted) context.pop(); })),
      body: Column(
        children: [
          Expanded(
            child: entriesAsync.when(
              data: (entries) => ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: entries.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final e = entries[i];
                  return Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [CircleAvatar(child: Text(e.guestName[0])), const SizedBox(width: 8), Text(e.guestName, style: const TextStyle(fontWeight: FontWeight.bold)), const Spacer(), Text('${e.date.hour}h${e.date.minute}', style: const TextStyle(fontSize: 11, color: Colors.grey))]),
                          const SizedBox(height: 8),
                          Text(e.message, style: const TextStyle(height: 1.4)),
                        ],
                      ),
                    ),
                  );
                },
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Erreur: $e')),
            ),
          ),
          Container(
            padding: EdgeInsets.only(left: 12, right: 12, bottom: MediaQuery.of(context).viewInsets.bottom + 12, top: 12),
            decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.grey.shade200))),
            child: Row(
              children: [
                Expanded(child: TextField(controller: _msgCtrl, decoration: InputDecoration(hintText: 'Laisser un message...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)), contentPadding: const EdgeInsets.symmetric(horizontal: 16)))),
                const SizedBox(width: 8),
                FilledButton(onPressed: postState.isLoading? null : _send, style: FilledButton.styleFrom(shape: const CircleBorder(), padding: const EdgeInsets.all(14), backgroundColor: const Color(0xFFE25A6A)), child: postState.isLoading? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.send)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
