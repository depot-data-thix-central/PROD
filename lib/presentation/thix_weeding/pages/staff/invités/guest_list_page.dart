// lib/presentation/thix_weeding/pages/staff/invités/guest_list_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// CENTRAUX
import 'package:thix_id/presentation/thix_weeding/pages/staff/models/thix_weeding_models.dart';
import 'package:thix_id/presentation/thix_weeding/pages/staff/providers/thix_weeding_providers.dart';
import 'package:thix_id/presentation/thix_weeding/pages/staff/services/thix_weeding_services.dart';

class GuestListPage extends ConsumerStatefulWidget {
  final String weddingId;
  const GuestListPage({super.key, required this.weddingId});
  @override
  ConsumerState<GuestListPage> createState() => _GuestListPageState();
}

class _GuestListPageState extends ConsumerState<GuestListPage> {
  String _search = '';
  String _filter = 'all'; // all, present, absent, confirmed

  @override
  Widget build(BuildContext context) {
    final guestsAsync = ref.watch(guestsProvider(widget.weddingId));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('Invités', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(icon: const Icon(Icons.person_add), onPressed: () => context.push('/thix-weeding/staff/${widget.weddingId}/invites/add')),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(children: [
              TextField(
                onChanged: (v) => setState(() => _search = v.toLowerCase()),
                decoration: InputDecoration(hintText: 'Rechercher nom, téléphone...', prefixIcon: const Icon(Icons.search, size: 20), filled: true, fillColor: const Color(0xFFF1F5F9), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  _FilterChip(label: 'Tous', value: 'all', selected: _filter, onTap: (v) => setState(() => _filter = v)),
                  _FilterChip(label: 'Présents', value: 'present', selected: _filter, onTap: (v) => setState(() => _filter = v)),
                  _FilterChip(label: 'Absents', value: 'absent', selected: _filter, onTap: (v) => setState(() => _filter = v)),
                  _FilterChip(label: 'Confirmés', value: 'confirmed', selected: _filter, onTap: (v) => setState(() => _filter = v)),
                ]),
              ),
            ]),
          ),
        ),
      ),
      body: guestsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur: $e')),
        data: (List<GuestModel> guests) {
          var filtered = guests.where((g) {
            final matchSearch = _search.isEmpty || g.fullName.toLowerCase().contains(_search) || (g.phone?? '').contains(_search);
            final matchFilter = _filter == 'all' || (_filter == 'present' && g.isPresent) || (_filter == 'absent' &&!g.isPresent) || (_filter == 'confirmed' && g.rsvpStatus == 'confirmed');
            return matchSearch && matchFilter;
          }).toList();

          if (filtered.isEmpty) {
            return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.people_outline, size: 48, color: Colors.grey), const SizedBox(height: 8), Text(_search.isNotEmpty? 'Aucun résultat' : 'Aucun invité', style: const TextStyle(color: Colors.grey)), const SizedBox(height: 12), FilledButton.icon(onPressed: () => context.push('/thix-weeding/staff/${widget.weddingId}/invites/add'), icon: const Icon(Icons.add), label: const Text('Ajouter invité'))]));
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(guestsProvider(widget.weddingId)),
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _GuestCard(guest: filtered[i], weddingId: widget.weddingId),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => context.push('/thix-weeding/staff/${widget.weddingId}/invites/add'), icon: const Icon(Icons.add), label: const Text('Invité')),
    );
  }
}

class _GuestCard extends ConsumerWidget {
  final GuestModel guest; final String weddingId;
  const _GuestCard({required this.guest, required this.weddingId});

  Future<void> _togglePresent(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(guestServiceProvider).togglePresent(guest.id, !guest.isPresent);
      ref.invalidate(guestsProvider(weddingId));
      ref.invalidate(dashboardStatsProvider(weddingId));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: const Text('Supprimer?'), content: Text('Supprimer ${guest.fullName}?'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Supprimer'))]));
    if (ok != true) return;
    try {
      await ref.read(guestServiceProvider).delete(guest.id);
      ref.invalidate(guestsProvider(weddingId));
      ref.invalidate(dashboardStatsProvider(weddingId));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
        child: ListTile(
          leading: CircleAvatar(backgroundColor: guest.isPresent? Colors.green.withOpacity(0.15) : const Color(0xFFEEF2FF), child: Text(guest.fullName.isNotEmpty? guest.fullName[0].toUpperCase() : '?', style: TextStyle(fontWeight: FontWeight.bold, color: guest.isPresent? Colors.green : const Color(0xFF0B3B8F)))),
          title: Text(guest.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${guest.rsvpStatus} • ${guest.phone?? '-'}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 4),
            Row(children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: guest.isPresent? Colors.green : Colors.orange.withOpacity(0.15), borderRadius: BorderRadius.circular(6)), child: Text(guest.isPresent? 'Présent' : 'Absent', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: guest.isPresent? Colors.white : Colors.orange))),
              const SizedBox(width: 6),
              if (guest.tableNumber != null) Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)), child: Text('Table ${guest.tableNumber}', style: const TextStyle(fontSize: 10))),
            ]),
          ]),
          trailing: PopupMenuButton(itemBuilder: (_) => [const PopupMenuItem(value: 'toggle', child: Text('Marquer présent/absent')), const PopupMenuItem(value: 'edit', child: Text('Modifier')), const PopupMenuItem(value: 'delete', child: Text('Supprimer', style: TextStyle(color: Colors.red)))], onSelected: (v) {
            if (v == 'toggle') _togglePresent(context, ref);
            if (v == 'edit') context.push('/thix-weeding/staff/$weddingId/invites/${guest.id}/edit');
            if (v == 'delete') _delete(context, ref);
          }),
          onTap: () => context.push('/thix-weeding/staff/$weddingId/invites/${guest.id}'),
        ),
      );
}

class _FilterChip extends StatelessWidget {
  final String label; final String value; final String selected; final Function(String) onTap;
  const _FilterChip({required this.label, required this.value, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final isSel = selected == value;
    return Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text(label, style: TextStyle(fontSize: 12, fontWeight: isSel? FontWeight.bold : FontWeight.normal)), selected: isSel, onSelected: (_) => onTap(value), selectedColor: const Color(0xFF0B3B8F), labelStyle: TextStyle(color: isSel? Colors.white : Colors.black87)));
  }
}
