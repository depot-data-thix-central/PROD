// lib/presentation/thix_weeding/pages/staff/invités/rsvp_management_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// CENTRAUX - juste guestsProvider
import 'package:thix_id/presentation/thix_weeding/pages/staff/models/thix_weeding_models.dart';
import 'package:thix_id/presentation/thix_weeding/pages/staff/providers/thix_weeding_providers.dart';

class RsvpManagementPage extends ConsumerWidget {
  final String weddingId;
  const RsvpManagementPage({super.key, required this.weddingId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final guestsAsync = ref.watch(guestsProvider(weddingId));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(title: const Text('Gestion RSVP'), backgroundColor: Colors.white),
      body: guestsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Erreur: $e')),
        data: (List<GuestModel> guests) {
          final total = guests.length;
          final yes = guests.where((g) => g.rsvpStatus == 'yes' || g.rsvpStatus == 'accepted').length;
          final no = guests.where((g) => g.rsvpStatus == 'no' || g.rsvpStatus == 'declined').length;
          final pending = guests.where((g) => g.rsvpStatus == 'pending').length;
          final maybe = guests.where((g) => g.rsvpStatus == 'maybe').length;

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(guestsProvider(weddingId)),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _StatsRow(total: total, yes: yes, no: no, pending: pending),
                const SizedBox(height: 20),
                const Text('Détails par invité - Temps réel DB', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                if (maybe > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text('$maybe peut-être', style: const TextStyle(color: Colors.orange, fontSize: 12)),
                  ),
                ...guests.map((g) => _GuestRsvpTile(guest: g)),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ================= INTERNES =================

class _StatsRow extends StatelessWidget {
  final int total, yes, no, pending;
  const _StatsRow({required this.total, required this.yes, required this.no, required this.pending});
  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(child: _StatCard(label: 'Total', value: total, color: Colors.blue)),
        const SizedBox(width: 8),
        Expanded(child: _StatCard(label: 'Confirmés', value: yes, color: Colors.green)),
        const SizedBox(width: 8),
        Expanded(child: _StatCard(label: 'Refusés', value: no, color: Colors.red)),
        const SizedBox(width: 8),
        Expanded(child: _StatCard(label: 'En attente', value: pending, color: Colors.grey)),
      ]);
}

class _StatCard extends StatelessWidget {
  final String label; final int value; final Color color;
  const _StatCard({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
        child: Column(children: [
          Text('$value', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
        ]),
      );
}

class _GuestRsvpTile extends StatelessWidget {
  final GuestModel guest;
  const _GuestRsvpTile({required this.guest});
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          leading: CircleAvatar(backgroundColor: const Color(0xFF0B3B8F).withOpacity(0.1), child: Text(guest.name[0].toUpperCase())),
          title: Text(guest.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          subtitle: Text('ID ${guest.id.substring(0, 8)} • ${guest.groupName}'),
          trailing: _Badge(status: guest.rsvpStatus),
        ),
      );
}

class _Badge extends StatelessWidget {
  final String status;
  const _Badge({required this.status});
  @override
  Widget build(BuildContext context) {
    Color c = status == 'yes' || status == 'accepted' ? Colors.green : status == 'no' || status == 'declined' ? Colors.red : status == 'maybe' ? Colors.orange : Colors.grey;
    return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: c.withOpacity(0.15), borderRadius: BorderRadius.circular(20)), child: Text(status, style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.bold)));
  }
}
