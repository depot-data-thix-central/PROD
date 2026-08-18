// lib/presentation/thix_sante/patient/screens/consulter_medecin_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/thix_sante_colors.dart';
import '../providers/doctor_provider.dart';
import '../models/doctor_model.dart';
import 'mon_medecin_traitant_page.dart';
import 'prendre_rdv_page.dart';

class ConsulterMedecinPage extends ConsumerStatefulWidget {
  const ConsulterMedecinPage({super.key});
  @override ConsumerState<ConsulterMedecinPage> createState()=> _ConsulterMedecinPageState();
}

class _ConsulterMedecinPageState extends ConsumerState<ConsulterMedecinPage> {
  String _q=''; String _spec='Tous';
  final _specs=['Tous','Généraliste','Cardiologue','Pédiatre','Gynécologue','Dermatologue'];
  @override Widget build(BuildContext context){
    final myDocs = ref.watch(myDoctorsProvider);
    final search = ref.watch(searchDoctorsProvider((query:_q, speciality:_spec)));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(backgroundColor: Colors.white, elevation:0, title: const Text('Consulter Médecin', style: TextStyle(fontWeight:FontWeight.w800, fontSize:18, color:Color(0xFF0F172A))), leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: ()=>Navigator.pop(context)), actions: [IconButton(icon: const Icon(Icons.person_add_alt_1, color:Color(0xFF0B63F6)), onPressed: ()=>Navigator.push(context, MaterialPageRoute(builder: (_)=> const MonMedecinTraitantPage())))]),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(16), child: Column(children: [
          TextField(onChanged: (v)=>setState(()=>_q=v.trim().toLowerCase()), decoration: InputDecoration(hintText:'Rechercher médecin, THIX ID...', prefixIcon: const Icon(Icons.search), filled:true, fillColor:Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none))),
          const SizedBox(height:12),
          SizedBox(height:36, child: ListView.separated(scrollDirection: Axis.horizontal, itemCount:_specs.length, separatorBuilder: (_,__ )=> const SizedBox(width:8), itemBuilder: (_,i){ final s=_specs[i]; final sel=s==_spec; return ChoiceChip(label:Text(s, style: TextStyle(fontSize:12, fontWeight: sel?FontWeight.w700:FontWeight.w500, color: sel?Colors.white:const Color(0xFF475569))), selected: sel, selectedColor: const Color(0xFF0B63F6), backgroundColor: Colors.white, onSelected: (_)=>setState(()=>_spec=s)); }))
        ])),
        Expanded(child: _q.isNotEmpty || _spec!='Tous'? search.when(data:(list)=> _buildList(list, isSearch:true), loading:()=>const Center(child:CircularProgressIndicator()), error:(e,_ )=>Center(child:Text('Erreur: $e'))) : myDocs.when(data:(list)=> _buildList(list, isSearch:false), loading:()=>const Center(child:CircularProgressIndicator()), error:(e,_ )=>Center(child:Text('Erreur: $e')))),
      ]),
    );
  }

  Widget _buildList(List<DoctorModel> docs, {required bool isSearch}){
    if(docs.isEmpty){
      return Center(child: Column(mainAxisAlignment:MainAxisAlignment.center, children: [Container(padding:const EdgeInsets.all(20), decoration: const BoxDecoration(color:Color(0xFFDBEAFE), shape:BoxShape.circle), child: const Icon(Icons.medical_services_outlined, size:40, color:Color(0xFF0B63F6))), const SizedBox(height:16), Text(isSearch?'Aucun résultat':'Aucun médecin lié', style: const TextStyle(fontWeight:FontWeight.w700)), const SizedBox(height:6), const Text('Ajoutez par THIX ID', style: TextStyle(fontSize:12, color:Color(0xFF94A3B8))), const SizedBox(height:16), ElevatedButton.icon(onPressed: ()=>Navigator.push(context, MaterialPageRoute(builder:(_)=>const MonMedecinTraitantPage())), icon: const Icon(Icons.add_link), label: const Text('Lier par THIX ID'), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0B63F6), foregroundColor: Colors.white))]));
    }
    return ListView.separated(padding: const EdgeInsets.symmetric(horizontal:16), itemCount: docs.length, separatorBuilder: (_,__ )=> const SizedBox(height:10), itemBuilder: (_,i){
      final doc = docs[i];
      return Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color:Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color:const Color(0xFFE2E8F0))), child: Row(children: [
        Stack(children: [CircleAvatar(radius:26, backgroundColor: const Color(0xFFDBEAFE), backgroundImage: doc.hasAvatar? NetworkImage(doc.avatarUrl!):null, child:!doc.hasAvatar? Text(doc.initials, style: const TextStyle(fontWeight:FontWeight.w800, color:Color(0xFF0B63F6))):null), Positioned(bottom:0,right:0,child:Container(width:12,height:12,decoration:BoxDecoration(color:const Color(0xFF22C55E),shape:BoxShape.circle,border:Border.all(color:Colors.white,width:2))))]),
        const SizedBox(width:12),
        Expanded(child: Column(crossAxisAlignment:CrossAxisAlignment.start, children: [Text(doc.fullName, style: const TextStyle(fontWeight:FontWeight.w800, fontSize:14)), Text(doc.displaySpeciality, style: const TextStyle(fontSize:12, color:Color(0xFF64748B))), const SizedBox(height:4), Row(children: [Container(padding:const EdgeInsets.symmetric(horizontal:6,vertical:2), decoration:BoxDecoration(color:const Color(0xFFFEF9C3), borderRadius:BorderRadius.circular(20)), child: Row(children:[const Icon(Icons.star_rounded,size:12,color:Color(0xFFEAB308)), const SizedBox(width:2), Text('${doc.rating??4.8}', style: const TextStyle(fontSize:10, fontWeight:FontWeight.w700))])), const SizedBox(width:6), Text(doc.thixId, style: const TextStyle(fontFamily:'monospace',fontSize:9,color:Color(0xFF94A3B8)))])])),
        Column(children: [IconButton.filled(onPressed: ()=>Navigator.push(context, MaterialPageRoute(builder:(_)=>PrendreRdvPage())), icon: const Icon(Icons.calendar_month_rounded, size:18), style: IconButton.styleFrom(backgroundColor: const Color(0xFF0B63F6), minimumSize: const Size(36,36))), const SizedBox(height:2), InkWell(onTap: (){}, child: Container(padding:const EdgeInsets.symmetric(horizontal:8,vertical:4), decoration:BoxDecoration(color:const Color(0xFFF1F5F9), borderRadius:BorderRadius.circular(20)), child: const Text('Chat', style: TextStyle(fontSize:10, fontWeight:FontWeight.w700))))])
      ]));
    });
  }
}
