// lib/presentation/thix_weeding/pages/staff/messages/staff_messages_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// CENTRAUX
import 'package:thix_id/presentation/thix_weeding/pages/staff/models/thix_weeding_models.dart';
import 'package:thix_id/presentation/thix_weeding/pages/staff/providers/thix_weeding_providers.dart';
final conversationsProvider = FutureProvider.family<List<MessageModel>, String>((ref, weddingId) async {
  final res = await Supabase.instance.client.from('thix_weeding_messages').select().eq('wedding_id', weddingId).order('created_at', ascending: false);
  final models = res.map((e) => MessageModel.fromJson(e)).toList();
  // group by guestId / senderName - garde dernier message
  final Map<String, MessageModel> grouped = {};
  for (var m in models) {
    final key = (m.guestId?? m.senderName).toString();
    if (!grouped.containsKey(key)) grouped[key] = m;
  }
  return grouped.values.toList();
});

class StaffMessagesPage extends ConsumerWidget {
  final String weddingId;
  const StaffMessagesPage({super.key, required this.weddingId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final convAsync = ref.watch(conversationsProvider(weddingId));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(title: const Text('Messages'), backgroundColor: Colors.white),
      body: convAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Erreur: $e')),
        data: (List<MessageModel> convs) {
          if (convs.isEmpty) return const Center(child: Text('Aucune discussion'));
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(conversationsProvider(weddingId)),
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: convs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final MessageModel c = convs[i];
                final unread =!c.isRead && c.senderType == 'guest';
                return _ConvTile(conversation: c, unread: unread, onTap: () => context.push('/thix-weeding/staff/$weddingId/messages/${c.guestId?? c.senderName}', extra: c.senderName));
              },
            ),
          );
        },
      ),
    );
  }
}

// ================= INTERNES =================

class _ConvTile extends StatelessWidget {
  final MessageModel conversation; final bool unread; final VoidCallback onTap;
  const _ConvTile({required this.conversation, required this.unread, required this.onTap});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
        child: ListTile(
          leading: Stack(children: [
            CircleAvatar(backgroundColor: const Color(0xFF0B3B8F).withOpacity(0.1), child: Text(conversation.senderName[0].toUpperCase(), style: const TextStyle(color: Color(0xFF0B3B8F), fontWeight: FontWeight.bold))),
            if (unread) Positioned(right: 0, top: 0, child: Container(width: 10, height: 10, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle))),
          ]),
          title: Row(children: [
            Expanded(child: Text(conversation.senderName, style: TextStyle(fontWeight: unread? FontWeight.w900 : FontWeight.bold, fontSize: 13))),
            if (unread) Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)), child: const Text('Nouveau', style: TextStyle(color: Colors.white, fontSize: 9))),
          ]),
          subtitle: Text(conversation.content, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
          trailing: Text('${conversation.createdAt.hour}:${conversation.createdAt.minute.toString().padLeft(2, '0')}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
          onTap: onTap,
        ),
      );
}
