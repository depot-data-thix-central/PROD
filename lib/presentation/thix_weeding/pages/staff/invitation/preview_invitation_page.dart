// lib/presentation/thix_weeding/pages/staff/invitation/preview_invitation_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

// NOUVEAUX IMPORTS ABSOLUS (Infaillibles)
import 'package:thix_id/presentation/thix_weeding/pages/staff/models/thix_weeding_models.dart';
import 'package:thix_id/presentation/thix_weeding/pages/staff/providers/thix_weeding_providers.dart';
import 'package:thix_id/presentation/thix_weeding/pages/staff/services/thix_weeding_services.dart';

final weddingInvitationProvider = FutureProvider.family<WeddingModel, String>((ref, weddingId) async {
  final data = await Supabase.instance.client.from('thix_weeding_weddings').select().eq('id', weddingId).single();
  return WeddingModel.fromJson(data);
});

class PreviewInvitationPage extends ConsumerWidget {
  final String weddingId;
  const PreviewInvitationPage({super.key, required this.weddingId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weddingAsync = ref.watch(weddingInvitationProvider(weddingId));

    return Scaffold(
      backgroundColor: const Color(0xFFF8F5F0),
      appBar: AppBar(title: const Text('Aperçu invitation'), backgroundColor: Colors.white, actions: [
        IconButton(icon: const Icon(Icons.edit), onPressed: () => context.push('/thix-weeding/staff/$weddingId/parametres')),
      ]),
      body: weddingAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Erreur: $e')),
        data: (WeddingModel w) {
          final invitationUrl = 'https://thix.id/w/$weddingId';

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _InvitationCard(wedding: w),
              const SizedBox(height: 24),
              _ShareCard(wedding: w, invitationUrl: invitationUrl, weddingId: weddingId, ref: ref),
              const SizedBox(height: 16),
              Text('Chaque invité recevra un lien unique avec son propre ID: https://thix.id/w/$weddingId?guest=UUID', style: const TextStyle(fontSize: 11, color: Colors.grey), textAlign: TextAlign.center),
            ],
          );
        },
      ),
    );
  }
}

// ================= INTERNES =================

class _InvitationCard extends StatelessWidget {
  final WeddingModel wedding;
  const _InvitationCard({required this.wedding});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 10))],
          border: Border.all(color: const Color(0xFFE8D5C4), width: 1),
        ),
        child: Column(children: [
          const Text('Nous nous marions !', style: TextStyle(letterSpacing: 2, fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 20),
          Text(wedding.brideName, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900)),
          const Text('&', style: TextStyle(fontSize: 24, color: Color(0xFFD4A373))),
          Text(wedding.groomName, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900)),
          const SizedBox(height: 20),
          Container(height: 1, width: 60, color: const Color(0xFFE8D5C4)),
          const SizedBox(height: 20),
          _IconRow(icon: Icons.calendar_today, text: wedding.weddingDate?.toString().substring(0, 10) ?? 'Date à définir'),
          const SizedBox(height: 8),
          _IconRow(icon: Icons.location_on, text: wedding.venue ?? 'Lieu à définir'),
          const SizedBox(height: 24),
          Text('ID Invitation: ${wedding.id.substring(0, 8)}', style: const TextStyle(fontSize: 10, color: Colors.grey, letterSpacing: 1)),
        ]),
      );
}

class _IconRow extends StatelessWidget {
  final IconData icon; final String text;
  const _IconRow({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 16, color: const Color(0xFF0B3B8F)),
        const SizedBox(width: 6),
        Flexible(child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
      ]);
}

class _ShareCard extends StatelessWidget {
  final WeddingModel wedding; final String invitationUrl; final String weddingId; final WidgetRef ref;
  const _ShareCard({required this.wedding, required this.invitationUrl, required this.weddingId, required this.ref});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Lien d\'invitation public', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          SelectableText(invitationUrl, style: const TextStyle(color: Colors.blue, fontSize: 13)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () async {
                  await Supabase.instance.client.from('thix_weeding_weddings').update({'invitation_published': true}).eq('id', weddingId);
                  
                  ref.invalidate(weddingInvitationProvider(weddingId));
                  // La fameuse ligne est réactivée !
                  ref.invalidate(weddingProvider(weddingId));
                  
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invitation publiée')));
                },
                icon: const Icon(Icons.public),
                label: Text(wedding.invitationPublished ? 'Déjà publiée' : 'Publier'),


              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: OutlinedButton.icon(onPressed: () => Share.share('Vous êtes invités au mariage de ${wedding.brideName} & ${wedding.groomName} le ${wedding.weddingDate} à ${wedding.venue}\n$invitationUrl'), icon: const Icon(Icons.share), label: const Text('Partager'))),
          ]),
        ]),
      );
}
