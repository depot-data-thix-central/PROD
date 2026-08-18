// lib/presentation/thix_weeding/pages/staff/my_weddings/my_weddings_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/presentation/thix_weeding/pages/staff/models/thix_weeding_models.dart';
import 'package:thix_id/presentation/thix_weeding/pages/staff/providers/thix_weeding_providers.dart';
import 'package:thix_id/presentation/thix_weeding/pages/staff/services/thix_weeding_services.dart';

class MyWeddingsPage extends ConsumerWidget {
  const MyWeddingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      return Scaffold(
        body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.lock_outline, size: 48, color: Colors.grey),
          const SizedBox(height: 12),
          const Text('Connectez-vous pour voir vos mariages'),
          const SizedBox(height: 12),
          FilledButton(onPressed: () => context.push('/thix-weeding/auth/login'), child: const Text('Se connecter')),
        ])),
      );
    }

    final weddingsAsync = ref.watch(myWeddingsProvider(user.id));

    return Scaffold(
      backgroundColor: const Color(0xFFFFFBFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('Mes mariages', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF241521))),
        actions: [IconButton(onPressed: () => context.push('/thix-weeding/create'), icon: const Icon(Icons.add_circle, color: Color(0xFFE31C4E)))],
      ),
      body: weddingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFE31C4E))),
        error: (e, _) => Center(child: Text('Erreur: $e')),
        data: (List<WeddingModel> weddings) {
          if (weddings.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: const Color(0xFFFFE3EA), shape: BoxShape.circle), child: const Icon(Icons.favorite_border_rounded, size: 48, color: Color(0xFFE31C4E))),
                  const SizedBox(height: 16),
                  const Text('Aucun mariage créé', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  const Text('Créez votre premier mariage pour accéder à l\'espace staff', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF8A7580))),
                  const SizedBox(height: 20),
                  FilledButton.icon(onPressed: () => context.push('/thix-weeding/create'), icon: const Icon(Icons.add), label: const Text('Créer mon mariage'), style: FilledButton.styleFrom(backgroundColor: const Color(0xFFE31C4E), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)))),
                ]),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(myWeddingsProvider(user.id)),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: weddings.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _WeddingCard(wedding: weddings[i]),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/thix-weeding/create'),
        backgroundColor: const Color(0xFFE31C4E),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Nouveau mariage', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class _WeddingCard extends ConsumerWidget {
  final WeddingModel wedding;
  const _WeddingCard({required this.wedding});

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: const Text('Supprimer ce mariage?'), content: const Text('Cette action est irréversible. Tous les invités, prestataires et paiements seront supprimés.'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')), FilledButton(onPressed: () => Navigator.pop(context, true), style: FilledButton.styleFrom(backgroundColor: Colors.red), child: const Text('Supprimer'))]));
    if (ok != true) return;
    try {
      await ref.read(weddingServiceProvider).delete(wedding.id);
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) ref.invalidate(myWeddingsProvider(userId));
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mariage supprimé')));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final daysLeft = wedding.date!= null? wedding.date!.difference(DateTime.now()).inDays.clamp(0, 999) : 0;
    return InkWell(
      onTap: () => context.push('/thix-weeding/staff/${wedding.id}'),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))]),
        child: Row(children: [
          Container(width: 56, height: 56, decoration: BoxDecoration(color: const Color(0xFFFFE3EA), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.favorite_rounded, color: Color(0xFFE31C4E))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(wedding.coupleNames?? 'Mariage sans nom', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF241521))),
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.calendar_today_outlined, size: 12, color: Color(0xFF8A7580)),
              const SizedBox(width: 4),
              Text(wedding.date?.toString().substring(0, 10)?? '-', style: const TextStyle(fontSize: 11, color: Color(0xFF8A7580))),
              const SizedBox(width: 10),
              const Icon(Icons.location_on_outlined, size: 12, color: Color(0xFF8A7580)),
              const SizedBox(width: 4),
              Expanded(child: Text(wedding.locationName?? '-', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Color(0xFF8A7580)))),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(20)), child: Text('ID: ${wedding.id.substring(0, 8).toUpperCase()}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF0B3B8F)))),
              const SizedBox(width: 6),
              if (daysLeft > 0) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: const Color(0xFFFFE3EA), borderRadius: BorderRadius.circular(20)), child: Text('J-$daysLeft', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFE31C4E)))),
            ]),
          ])),
          Column(children: [
            IconButton(onPressed: () => context.push('/thix-weeding/guest/${wedding.id}/invitation'), icon: const Icon(Icons.visibility_outlined, size: 20)),
            PopupMenuButton(itemBuilder: (_) => [const PopupMenuItem(value: 'edit', child: Text('Modifier')), const PopupMenuItem(value: 'delete', child: Text('Supprimer', style: TextStyle(color: Colors.red)))], onSelected: (v) {
              if (v == 'edit') context.push('/thix-weeding/edit/${wedding.id}');
              if (v == 'delete') _delete(context, ref);
            }),
          ]),
        ]),
      ),
    );
  }
}
