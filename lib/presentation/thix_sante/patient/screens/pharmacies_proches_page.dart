// lib/presentation/thix_sante/patient/screens/pharmacies_proches_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/thix_sante_colors.dart';
import '../providers/pharmacie_provider.dart';

class PharmaciesProchesPage extends ConsumerWidget {
  const PharmaciesProchesPage({super.key});

  Future<void> _call(String tel) async {
    final uri = Uri.parse('tel:$tel');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _map(double lat, double lng) async {
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncPharmas = ref.watch(pharmaciesProchesProvider);
    final asyncGardes = ref.watch(pharmaciesGardeProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF111827)), onPressed: ()=> Navigator.pop(context)),
        title: const Text('Pharmacies proches', style: TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.w800)),
        actions: [IconButton(icon: const Icon(Icons.my_location_rounded, color: Color(0xFF0B63F6)), onPressed: (){ ref.invalidate(positionProvider); ref.invalidate(pharmaciesProchesProvider); })],
      ),
      body: Column(children: [
        asyncGardes.when(
          data: (gardes) => gardes.isEmpty? const SizedBox() : Container(
            height: 96, color: Colors.white, padding: const EdgeInsets.symmetric(vertical:10),
            child: ListView.builder(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal:16), itemCount: gardes.length, itemBuilder: (_,i){
              final g = gardes[i];
              return Container(margin: const EdgeInsets.only(right:10), width: 200, padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFFECACA))), child: Row(children:[
                Container(width:36,height:36,decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.local_pharmacy_rounded, color: Colors.white, size:18)),
                const SizedBox(width:8),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[Text(g['nom'], maxLines:1, overflow:TextOverflow.ellipsis, style: const TextStyle(fontSize:11, fontWeight: FontWeight.w800)), const Text('DE GARDE', style: TextStyle(fontSize:9, fontWeight: FontWeight.w700, color: Colors.red)), Text(g['quartier']??'', style: const TextStyle(fontSize:10, color: Color(0xFF6B7280)))]))
              ]));
            }),
          ),
          loading: ()=> const SizedBox(), error: (_,__)=> const SizedBox(),
        ),
        Expanded(child: asyncPharmas.when(
          loading: ()=> const Center(child: CircularProgressIndicator()),
          error: (e,_)=> Center(child: Column(mainAxisSize: MainAxisSize.min, children:[Text('Erreur: $e'), const SizedBox(height:8), ElevatedButton(onPressed: ()=> ref.invalidate(pharmaciesProchesProvider), child: const Text('Réessayer'))])),
          data: (list){
            if(list.isEmpty) return const Center(child: Text('Aucune pharmacie dans 10km'));
            return ListView.builder(padding: const EdgeInsets.all(16), itemCount: list.length, itemBuilder: (_,i){
              final p = list[i];
              final dist = (p['distance_km'] as num?)?.toDouble()?? 0;
              return Container(
                margin: const EdgeInsets.only(bottom:12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE5E7EB))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
                  Row(children:[
                    Container(width:48,height:48,decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.local_pharmacy_rounded, color: Color(0xFF0B63F6))),
                    const SizedBox(width:12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
                      Row(children:[Expanded(child: Text(p['nom'], style: const TextStyle(fontWeight: FontWeight.w800, fontSize:13))), if(p['is_garde']==true) Container(padding: const EdgeInsets.symmetric(horizontal:6,vertical:2), decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(6)), child: const Text('GARDE', style: TextStyle(color: Colors.white, fontSize:8, fontWeight: FontWeight.w800)))]),
                      Text('${p['adresse']} • ${dist.toStringAsFixed(1)} km', style: const TextStyle(fontSize:11, color: Color(0xFF6B7280)), maxLines:1),
                      Row(children:[const Icon(Icons.star_rounded, size:12, color: Color(0xFFF59E0B)), Text('${p['rating']??'4.5'}', style: const TextStyle(fontSize:11)), const SizedBox(width:8), Text(p['is_open']? 'Ouvert' : 'Fermé', style: TextStyle(fontSize:11, color: p['is_open']? const Color(0xFF16A34A) : Colors.red, fontWeight: FontWeight.w700))]),
                    ])),
                  ]),
                  const SizedBox(height:12),
                  Row(children:[
                    Expanded(child: OutlinedButton.icon(onPressed: ()=> _call(p['telephone']??''), icon: const Icon(Icons.call_rounded, size:16), label: const Text('Appeler', style: TextStyle(fontSize:12)), style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))))),
                    const SizedBox(width:8),
                    Expanded(child: ElevatedButton.icon(onPressed: ()=> _map((p['latitude'] as num).toDouble(), (p['longitude'] as num).toDouble()), icon: const Icon(Icons.directions_rounded, size:16), label: const Text('Itinéraire', style: TextStyle(fontSize:12)), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0B63F6), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))))),
                  ]),
                  const SizedBox(height:6),
                  SelectableText('THIX ID: ${p['thix_id']}', style: const TextStyle(fontSize:10, color: Color(0xFF9CA3AF), fontFamily: 'monospace')),
                ]),
              );
            });
          },
        )),
      ]),
    );
  }
}
