// lib/presentation/thix_weeding/pages/guest/invitation_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/wedding_provider.dart';
import 'package:intl/intl.dart';

class InvitationPage extends ConsumerWidget {
  final String weddingId;
  const InvitationPage({super.key, required this.weddingId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weddingAsync = ref.watch(guestWeddingProvider(weddingId));

    return Scaffold(
      appBar: AppBar(title: const Text('Invitation'), leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () { if (context.mounted) context.pop(); })),
      body: weddingAsync.when(
        data: (wedding) {
          final dateStr = DateFormat('EEEE d MMMM yyyy à HH:mm', 'fr_FR').format(wedding.date);
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: Image.network(wedding.coverImageUrl, height: 260, width: double.infinity, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(height: 260, color: Colors.pink.shade50))),
              SliverPadding(
                padding: const EdgeInsets.all(20),
                sliver: SliverList.list(children: [
                  Text(wedding.coupleNames, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFFB84B5A))),
                  const SizedBox(height: 12),
                  Text(wedding.welcomeMessage, style: const TextStyle(fontSize: 16, height: 1.5)),
                  const SizedBox(height: 24),
                  _InfoRow(icon: Icons.calendar_today, title: 'Date', value: dateStr),
                  const SizedBox(height: 16),
                  _InfoRow(icon: Icons.location_on, title: 'Lieu', value: '${wedding.locationName}\n${wedding.locationAddress}'),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton.icon(onPressed: () {}, icon: const Icon(Icons.event), label: const Text('Ajouter à mon calendrier'), style: FilledButton.styleFrom(backgroundColor: const Color(0xFFE25A6A))),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(width: double.infinity, height: 52, child: OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.share), label: const Text('Partager l’invitation'))),
                ]),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur: $e')),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  const _InfoRow({required this.icon, required this.title, required this.value});
  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      CircleAvatar(backgroundColor: Colors.pink.shade50, child: Icon(icon, color: Colors.pink)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 4), Text(value, style: const TextStyle(color: Colors.black87, height: 1.4))])),
    ]);
  }
}
