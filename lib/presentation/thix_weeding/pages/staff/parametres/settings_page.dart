// lib/presentation/thix_weeding/pages/staff/parametres/settings_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final settingsProvider = FutureProvider.family<Map<String,dynamic>, String>((ref, weddingId) async {
  return await Supabase.instance.client.from('thix_weeding_weddings').select().eq('id', weddingId).single();
});

class SettingsPage extends ConsumerWidget {
  final String weddingId;
  const SettingsPage({super.key, required this.weddingId});
  @override Widget build(BuildContext context, WidgetRef ref){
    final async = ref.watch(settingsProvider(weddingId));
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(title: const Text('Paramètres'), backgroundColor: Colors.white),
      body: async.when(
        loading: ()=> const Center(child: CircularProgressIndicator()),
        error: (e,s)=> Center(child: Text('$e')),
        data: (w)=> ListView(padding: const EdgeInsets.all(16), children: [
          Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${w['bride_name']??''} & ${w['groom_name']??''}', style: const TextStyle(fontSize:18, fontWeight: FontWeight.w900)),
            Text('ID: ${w['id']} • Code: ${w['unique_code']??'-'}', style: const TextStyle(fontSize:11, color: Colors.grey)),
          ])),
          const SizedBox(height:16),
          _Tile(icon: Icons.edit, title:'Informations mariage', subtitle:'Noms, date, lieu', onTap: ()=> context.push('/thix-weeding/staff/$weddingId/parametres/infos')),
          _Tile(icon: Icons.card_giftcard, title:'Invitation', subtitle:'Aperçu et publication', onTap: ()=> context.push('/thix-weeding/staff/$weddingId/invitation/preview')),
          _Tile(icon: Icons.people, title:'Gérer les accès', subtitle:'Partager le code organisateur', onTap: ()=> _showCode(context, w)),
          _Tile(icon: Icons.delete_forever, title:'Supprimer mariage', subtitle:'Action irréversible', isDestructive: true, onTap: ()=> _confirmDelete(context, weddingId)),
          const SizedBox(height:20),
          const Text('Données 100% Supabase • Chaque entité a son ID uuid unique', style: TextStyle(fontSize:10, color: Colors.grey), textAlign: TextAlign.center),
        ]),
      ),
    );
  }

  void _showCode(BuildContext context, Map<String,dynamic> w){
    showDialog(context: context, builder: (_)=> AlertDialog(title: const Text('Code organisateur'), content: SelectableText('Code: ${w['unique_code']}\nPartagez ce code pour donner accès staff'), actions: [TextButton(onPressed: ()=> Navigator.pop(context), child: const Text('Fermer'))]));
  }

  void _confirmDelete(BuildContext context, String weddingId){
    showDialog(context: context, builder: (_)=> AlertDialog(title: const Text('Supprimer définitivement?'), content: const Text('Toutes les données (invités, prestataires, budget, galerie) seront supprimées.'), actions: [
      TextButton(onPressed: ()=> Navigator.pop(context), child: const Text('Annuler')),
      FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red), onPressed: () async {
        await Supabase.instance.client.from('thix_weeding_weddings').delete().eq('id', weddingId);
        if(context.mounted){ Navigator.pop(context); context.go('/thix-weeding'); }
      }, child: const Text('Supprimer')),
    ]));
  }
}
class _Tile extends StatelessWidget{ final IconData icon; final String title; final String subtitle; final VoidCallback onTap; final bool isDestructive; const _Tile({required this.icon, required this.title, required this.subtitle, required this.onTap, this.isDestructive=false}); @override Widget build(BuildContext context)=> Container(margin: const EdgeInsets.only(bottom:8), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)), child: ListTile(leading: Icon(icon, color: isDestructive?Colors.red:const Color(0xFF0B3B8F)), title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: isDestructive?Colors.red:null)), subtitle: Text(subtitle), trailing: const Icon(Icons.chevron_right), onTap: onTap)); }
