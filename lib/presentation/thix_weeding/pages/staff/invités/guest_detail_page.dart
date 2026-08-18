// lib/presentation/thix_weeding/pages/staff/invités/guest_detail_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

// CENTRAUX
import 'package:thix_id/presentation/thix_weeding/pages/staff/models/thix_weeding_models.dart';
import 'package:thix_id/presentation/thix_weeding/pages/staff/providers/thix_weeding_providers.dart';

final guestDetailProvider = FutureProvider.family<GuestModel, String>((ref, guestId) async {
  final data = await Supabase.instance.client.from('thix_weeding_guests').select().eq('id', guestId).single();
  return GuestModel.fromJson(data);
});

class GuestDetailPage extends ConsumerWidget {
  final String weddingId;
  final String guestId;
  const GuestDetailPage({super.key, required this.weddingId, required this.guestId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final guestAsync = ref.watch(guestDetailProvider(guestId));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Détail invité'),
        backgroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _confirmDelete(context, ref)),
        ],
      ),
      body: guestAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Erreur: $e')),
        data: (GuestModel g) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _HeaderCard(guest: g),
            const SizedBox(height: 16),
            _InfoCard(guest: g),
            const SizedBox(height: 20),
            _ActionsRow(weddingId: weddingId, guest: g),
            const SizedBox(height: 16),
            _InviteLink(weddingId: weddingId, guestId: g.id),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer invité?'),
        content: const Text('Suppression définitive.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(context, true), style: FilledButton.styleFrom(backgroundColor: Colors.red), child: const Text('Supprimer')),
        ],
      ),
    );
    if (ok!= true) return;

    try {
      await Supabase.instance.client.from('thix_weeding_guests').delete().eq('id', guestId);
      ref.invalidate(guestsProvider(weddingId));
      ref.invalidate(guestDetailProvider(guestId));
      if (context.mounted) context.pop();
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }
}

// ================= WIDGETS INTERNES =================

class _HeaderCard extends StatelessWidget {
  final GuestModel guest;
  const _HeaderCard({required this.guest});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Column(children: [
          CircleAvatar(radius: 40, backgroundColor: const Color(0xFF0B3B8F).withOpacity(0.1), child: Text(guest.name.isNotEmpty? guest.name[0].toUpperCase() : '?', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF0B3B8F)))),
          const SizedBox(height: 12),
          Text(guest.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900), textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text('ID: ${guest.id.substring(0, 8)}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
          const SizedBox(height: 8),
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: _rsvpColor(guest.rsvpStatus).withOpacity(0.1), borderRadius: BorderRadius.circular(20)), child: Text(guest.rsvpStatus, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _rsvpColor(guest.rsvpStatus)))),
        ]),
      );

  Color _rsvpColor(String status) {
    switch (status) {
      case 'accepted': return Colors.green;
      case 'declined': return Colors.red;
      default: return Colors.orange;
    }
  }
}

class _InfoCard extends StatelessWidget {
  final GuestModel guest;
  const _InfoCard({required this.guest});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Column(children: [
          _RowInfo(icon: Icons.group, label: 'Groupe', value: guest.groupName),
          _RowInfo(icon: Icons.phone, label: 'Téléphone', value: guest.phone?? 'Non renseigné'),
          _RowInfo(icon: Icons.email, label: 'Email', value: guest.email?? 'Non renseigné'),
          _RowInfo(icon: Icons.people, label: 'Nombre', value: '${guest.guestsCount} personnes'),
          _RowInfo(icon: Icons.table_restaurant, label: 'Table', value: guest.tableNumber?.toString()?? 'Non assignée'),
          _RowInfo(icon: Icons.check_circle, label: 'RSVP', value: guest.rsvpStatus),
        ]),
      );
}

class _ActionsRow extends StatelessWidget {
  final String weddingId; final GuestModel guest;
  const _ActionsRow({required this.weddingId, required this.guest});
  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(child: OutlinedButton.icon(onPressed: () => context.push('/thix-weeding/staff/$weddingId/invites/add?edit=${guest.id}'), icon: const Icon(Icons.edit), label: const Text('Modifier'))),
        const SizedBox(width: 12),
        Expanded(child: FilledButton.icon(onPressed: () {}, icon: const Icon(Icons.share), label: const Text('Partager'))),
      ]);
}

class _InviteLink extends StatelessWidget {
  final String weddingId; final String guestId;
  const _InviteLink({required this.weddingId, required this.guestId});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.blue.withOpacity(0.06), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blue.withOpacity(0.2))),
        child: SelectableText('Lien invitation: https://thix.id/w/$weddingId?guest=$guestId', style: const TextStyle(fontSize: 12, color: Colors.blue)),
      );
}

class _RowInfo extends StatelessWidget {
  final IconData icon; final String label; final String value;
  const _RowInfo({required this.icon, required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFF0B3B8F).withOpacity(0.08), borderRadius: BorderRadius.circular(8)), child: Icon(icon, size: 18, color: const Color(0xFF0B3B8F))),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)), const SizedBox(height: 2), Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))]),
        ]),
      );
}
