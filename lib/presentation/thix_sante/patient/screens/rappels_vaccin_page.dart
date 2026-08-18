// lib/presentation/thix_sante/patient/screens/rappels_vaccin_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/thix_sante_colors.dart';

class RappelsVaccinPage extends StatefulWidget {
  const RappelsVaccinPage({super.key});
  @override State<RappelsVaccinPage> createState() => _RappelsVaccinPageState();
}

class _RappelsVaccinPageState extends State<RappelsVaccinPage> {
  final _db = Supabase.instance.client;
  List<Map<String,dynamic>> _vaccins = [];
  bool _loading = true;
  String _filter = 'Tous';

  @override
  void initState(){ super.initState(); _load(); }

  Future<void> _load() async {
    final uid = _db.auth.currentUser?.id;
    if(uid==null){ if(mounted) setState(()=>_loading=false); return; }
    try{
      final res = await _db.from('vaccinations').select('*').eq('patient_id', uid).order('date_prevue', ascending:true);
      if(mounted) setState(()=> _vaccins = List<Map<String,dynamic>>.from(res));
    }catch(_){ if(mounted) setState(()=> _vaccins = []); }
    finally{ if(mounted) setState(()=>_loading=false); }
  }

  Future<void> _marquerFait(String id) async {
    await _db.from('vaccinations').update({'statut':'fait','date_realisee':DateTime.now().toIso8601String()}).eq('id', id);
    _load();
  }

  Future<void> _addVaccin() async {
    final nomCtrl = TextEditingController();
    DateTime date = DateTime.now().add(const Duration(days:30));
    await showModalBottomSheet(context:context, isScrollControlled:true, backgroundColor:Colors.white, shape:const RoundedRectangleBorder(borderRadius:BorderRadius.vertical(top:Radius.circular(20))), builder:(c)=> StatefulBuilder(builder:(c,setS)=> Padding(padding:EdgeInsets.only(bottom:MediaQuery.of(c).viewInsets.bottom, left:16,right:16,top:20), child:Column(mainAxisSize:MainAxisSize.min, children:[
      const Text('Ajouter un vaccin',style:TextStyle(fontWeight:FontWeight.w800,fontSize:16)),
      const SizedBox(height:14),
      TextField(controller:nomCtrl, decoration:InputDecoration(hintText:'Ex: Hepatite B, COVID', filled:true,fillColor:const Color(0xFFF8FAFC),border:OutlineInputBorder(borderRadius:BorderRadius.circular(12),borderSide:BorderSide.none))),
      const SizedBox(height:12),
      ListTile(leading:const Icon(Icons.calendar_today_rounded), title:Text('${date.day}/${date.month}/${date.year}'), trailing:const Icon(Icons.edit_rounded), onTap:() async { final d=await showDatePicker(context:c, initialDate:date, firstDate:DateTime.now(), lastDate:DateTime.now().add(const Duration(days:1825))); if(d!=null) setS(()=>date=d); }),
      const SizedBox(height:16),
      SizedBox(width:double.infinity, child:ElevatedButton(onPressed:() async {
        final uid=_db.auth.currentUser?.id; if(uid==null||nomCtrl.text.trim().isEmpty) return;
        await _db.from('vaccinations').insert({'patient_id':uid,'vaccin_nom':nomCtrl.text.trim(),'date_prevue':date.toIso8601String(),'statut':'prevu','dose_num':1});
        if(context.mounted) Navigator.pop(context); _load();
      }, style:ElevatedButton.styleFrom(backgroundColor:ThixSanteColors.primary,foregroundColor:Colors.white,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(12)),padding:const EdgeInsets.symmetric(vertical:14)), child:const Text('Enregistrer'))),
      const SizedBox(height:20),
    ]))));
  }

  @override
  Widget build(BuildContext context){
    final filtered = _filter=='Tous'? _vaccins : _vaccins.where((v)=> v['statut']==_filter.toLowerCase()).toList();
    final enRetard = _vaccins.where((v){ final d=v['date_prevue']!=null?DateTime.tryParse(v['date_prevue'].toString()):null; return d!=null && d.isBefore(DateTime.now()) && v['statut']!='fait'; }).length;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(backgroundColor:Colors.white, elevation:0, leading:IconButton(icon:const Icon(Icons.arrow_back_rounded,color:Color(0xFF0F172A)),onPressed:()=>Navigator.pop(context)), title:const Text('Rappels vaccin',style:TextStyle(fontWeight:FontWeight.w800,fontSize:16,color:Color(0xFF0F172A))), actions:[IconButton(icon:const Icon(Icons.add_rounded,color:ThixSanteColors.primary),onPressed:_addVaccin)]),
      floatingActionButton: FloatingActionButton.extended(onPressed:_addVaccin, backgroundColor:ThixSanteColors.primary, foregroundColor:Colors.white, icon:const Icon(Icons.add_rounded), label:const Text('Ajouter')),
      body: _loading? const Center(child:CircularProgressIndicator(strokeWidth:2)) : ListView(padding:const EdgeInsets.all(16), children:[
        if(enRetard>0) Container(margin:const EdgeInsets.only(bottom:16), padding:const EdgeInsets.all(14), decoration:BoxDecoration(color:const Color(0xFFFEF2F2),borderRadius:BorderRadius.circular(14),border:Border.all(color:const Color(0xFFFECACA))), child:Row(children:[Container(padding:const EdgeInsets.all(8), decoration:const BoxDecoration(color:Colors.white,shape:BoxShape.circle), child:const Icon(Icons.warning_rounded,color:Color(0xFFDC2626),size:20)),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('$enRetard vaccin(s) en retard',style:const TextStyle(fontWeight:FontWeight.w800,color:Color(0xFFDC2626),fontSize:13)),const Text('Prenez rendez-vous rapidement',style:TextStyle(fontSize:11,color:Color(0xFF991B1B)))])),])),
        Wrap(spacing:8, children:['Tous','prevu','fait'].map((f)=> ChoiceChip(label:Text(f), selected:_filter==f, selectedColor:ThixSanteColors.primary, labelStyle:TextStyle(color:_filter==f?Colors.white:const Color(0xFF0F172A),fontSize:12), backgroundColor:Colors.white, onSelected:(_)=>setState(()=>_filter=f))).toList()),
        const SizedBox(height:16),
        if(filtered.isEmpty) Container(padding:const EdgeInsets.all(30), decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(16),border:Border.all(color:const Color(0xFFE2E8F0))), child:Column(children:[Container(padding:const EdgeInsets.all(16), decoration:const BoxDecoration(color:Color(0xFFDBEAFE),shape:BoxShape.circle), child:const Icon(Icons.vaccines_rounded,color:ThixSanteColors.primary,size:32)),const SizedBox(height:12),const Text('Aucun vaccin',style:TextStyle(fontWeight:FontWeight.w700)),const SizedBox(height:4),const Text('Ajoutez vos vaccins pour recevoir des rappels',style:TextStyle(fontSize:12,color:Color(0xFF64748B)),textAlign:TextAlign.center)])),
        ...filtered.map((v){
          final date = v['date_prevue']!=null? DateTime.tryParse(v['date_prevue'].toString()):null;
          final isFait = v['statut']=='fait';
          final isRetard = date!=null && date.isBefore(DateTime.now()) && !isFait;
          return Container(margin:const EdgeInsets.only(bottom:10), padding:const EdgeInsets.all(14), decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(16),border:Border.all(color:isRetard?const Color(0xFFFECACA):const Color(0xFFE2E8F0))), child:Row(children:[
            Container(width:48,height:48, decoration:BoxDecoration(color:isFait?const Color(0xFFDCFCE7):isRetard?const Color(0xFFFEF2F2):const Color(0xFFDBEAFE),borderRadius:BorderRadius.circular(12)), child:Icon(isFait?Icons.check_rounded:isRetard?Icons.warning_rounded:Icons.vaccines_rounded, color:isFait?const Color(0xFF16A34A):isRetard?const Color(0xFFDC2626):ThixSanteColors.primary)),
            const SizedBox(width:12),
            Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(v['vaccin_nom']??'Vaccin',style:const TextStyle(fontWeight:FontWeight.w800,fontSize:14)),const SizedBox(height:2),Text(date!=null?'Prev le ${date.day}/${date.month}/${date.year}':'Date non definie',style:const TextStyle(fontSize:11,color:Color(0xFF64748B))),const SizedBox(height:4),Container(padding:const EdgeInsets.symmetric(horizontal:8,vertical:3), decoration:BoxDecoration(color:isFait?const Color(0xFFDCFCE7):isRetard?const Color(0xFFFEF2F2):const Color(0xFFFFEDD5),borderRadius:BorderRadius.circular(20)), child:Text(isFait?'Fait':isRetard?'En retard':'Prevu',style:TextStyle(fontSize:10,fontWeight:FontWeight.w700,color:isFait?const Color(0xFF16A34A):isRetard?const Color(0xFFDC2626):const Color(0xFFEA580C))))])),
            if(!isFait) IconButton.filled(onPressed:()=>_marquerFait(v['id'].toString()), icon:const Icon(Icons.check_rounded,size:18), style:IconButton.styleFrom(backgroundColor:ThixSanteColors.primary,foregroundColor:Colors.white,minimumSize:const Size(36,36)))
          ]));
        }),
      ]),
    );
  }
}
