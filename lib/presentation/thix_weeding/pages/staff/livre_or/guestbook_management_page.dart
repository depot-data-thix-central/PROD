// lib/presentation/thix_weeding/pages/staff/livre_or/guestbook_management_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Imports des modèles et providers centraux
import 'package:thix_id/presentation/thix_weeding/pages/staff/models/thix_weeding_models.dart';
import 'package:thix_id/presentation/thix_weeding/pages/staff/providers/thix_weeding_providers.dart';
import 'package:thix_id/presentation/thix_weeding/pages/staff/services/thix_weeding_services.dart';



class GuestbookManagementPage extends ConsumerStatefulWidget {
  final String weddingId;
  const GuestbookManagementPage({super.key, required this.weddingId});
  @override
  ConsumerState<GuestbookManagementPage> createState() => _GuestbookManagementPageState();
}

class _GuestbookManagementPageState extends ConsumerState<GuestbookManagementPage> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final guestbookAsync = ref.watch(guestbookProvider(widget.weddingId));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(title: const Text('Livre d\'or'), backgroundColor: Colors.white, actions: [
        IconButton(icon: const Icon(Icons.refresh), onPressed: () => ref.invalidate(guestbookProvider(widget.weddingId))),
      ]),
      body: guestbookAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Erreur: $e')),
        data: (List<GuestbookModel> messages) {
          final filtered = messages.where((m) {
            if (_filter == 'approved') return m.isApproved;
            if (_filter == 'pending') return!m.isApproved;
            return true;
          }).toList();

          return Column(children: [
            _StatsRow(messages: messages),
            _FilterRow(filter: _filter, onChanged: (v) => setState(() => _filter = v)),
            const SizedBox(height: 8),
            Expanded(child: filtered.isEmpty ? const Center(child: Text('Aucun message')) : _MessageList(messages: filtered, weddingId: widget.weddingId)),
          ]);
        },
      ),
    );
  }
}

// ================= INTERNES =================

class _StatsRow extends StatelessWidget {
  final List<GuestbookModel> messages;
  const _StatsRow({required this.messages});
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          _StatBox(label: 'Total', value: messages.length, color: const Color(0xFF0B3B8F)),
          const SizedBox(width: 12),
          _StatBox(label: 'Approuvés', value: messages.where((m) => m.isApproved).length, color: Colors.green),
          const SizedBox(width: 12),
          _StatBox(label: 'En attente', value: messages.where((m) =>!m.isApproved).length, color: Colors.orange),
        ]),
      );
}

class _FilterRow extends StatelessWidget {
  final String filter; final Function(String) onChanged;
  const _FilterRow({required this.filter, required this.onChanged});
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(children: [
          _Chip(label: 'Tous', sel: filter == 'all', tap: () => onChanged('all')),
          _Chip(label: 'Approuvés', sel: filter == 'approved', tap: () => onChanged('approved')),
          _Chip(label: 'En attente', sel: filter == 'pending', tap: () => onChanged('pending')),
        ]),
      );
}

class _MessageList extends ConsumerWidget {
  final List<GuestbookModel> messages; final String weddingId;
  const _MessageList({required this.messages, required this.weddingId});

  @override
  Widget build(BuildContext context, WidgetRef ref) => RefreshIndicator(
        onRefresh: () async => ref.invalidate(guestbookProvider(weddingId)),
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: messages.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) {
            final GuestbookModel m = messages[i];
            return Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border(left: BorderSide(color: m.isApproved? Colors.green : Colors.orange, width: 4))),
              child: ListTile(
                leading: CircleAvatar(child: Text(m.guestName[0].toUpperCase())),
                title: Row(children: [
                  Expanded(child: Text(m.guestName, style: const TextStyle(fontWeight: FontWeight.bold))),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: m.isApproved? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Text(m.isApproved? 'Publié' : 'Masqué', style: TextStyle(fontSize: 10, color: m.isApproved? Colors.green : Colors.orange))),
                ]),
                subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const SizedBox(height: 4),
                  Text(m.message),
                  const SizedBox(height: 6),
                  Text('ID: ${m.id.substring(0, 8)} • ${m.createdAt.day}/${m.createdAt.month}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                ]),
                trailing: PopupMenuButton(
                  onSelected: (v) async {
                    if (v == 'toggle') {
                      await Supabase.instance.client.from('thix_weeding_guestbook').update({'is_approved':!m.isApproved}).eq('id', m.id);
                      ref.invalidate(guestbookProvider(weddingId));
                    }
                    if (v == 'delete') {
                      await Supabase.instance.client.from('thix_weeding_guestbook').delete().eq('id', m.id);
                      ref.invalidate(guestbookProvider(weddingId));
                    }
                  },
                  itemBuilder: (_) => [PopupMenuItem(value: 'toggle', child: Text(m.isApproved? 'Masquer' : 'Approuver')), const PopupMenuItem(value: 'delete', child: Text('Supprimer', style: TextStyle(color: Colors.red)))],
                ),
              ),
            );
          },
        ),
      );
}

class _StatBox extends StatelessWidget {
  final String label; final int value; final Color color;
  const _StatBox({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Expanded(child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Column(children: [Text('$value', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color)), Text(label, style: TextStyle(fontSize: 11, color: color))]))); 
}

class _Chip extends StatelessWidget {
  final String label; final bool sel; final VoidCallback tap;
  const _Chip({required this.label, required this.sel, required this.tap});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text(label), selected: sel, selectedColor: const Color(0xFF0B3B8F).withOpacity(0.15), onSelected: (_) => tap()));
}
