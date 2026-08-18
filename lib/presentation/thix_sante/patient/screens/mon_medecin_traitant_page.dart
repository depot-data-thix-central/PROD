// lib/presentation/thix_sante/patient/screens/mon_medecin_traitant_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/thix_id_validator.dart';
import '../../core/thix_sante_colors.dart';
import '../models/doctor_profile_model.dart';
import '../providers/patient_link_provider.dart';

class MonMedecinTraitantPage extends ConsumerStatefulWidget {
  const MonMedecinTraitantPage({super.key});
  @override ConsumerState<MonMedecinTraitantPage> createState()=> _MonMedecinTraitantPageState();
}

class _MonMedecinTraitantPageState extends ConsumerState<MonMedecinTraitantPage> {
  final _ctrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _searching=false; bool _linking=false;
  DoctorProfileModel? _found; String? _err;

  Future<void> _search() async {
    if(!_formKey.currentState!.validate()) return;
    setState((){_searching=true; _err=null; _found=null;});
    try{
      final doc = await ref.read(patientLinkServiceProvider).findDoctorByThixId(_ctrl.text);
      setState(()=>_found=doc);
    }catch(e){ setState(()=>_err=e.toString().replaceAll('Exception: ', '')); }
    finally{ if(mounted) setState(()=>_searching=false); }
  }

  Future<void> _link() async {
    if(_found==null) return;
    setState(()=>_linking=true);
    try{
      await ref.read(patientLinkServiceProvider).requestDoctorByThixId(doctorThixId: _found!.thixId);
      ref.invalidate(myLinkedDoctorsProvider);
      if(!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lié au Dr ${_found!.fullName}'), backgroundColor: const Color(0xFF16A34A)));
      Navigator.pop(context);
    }catch(e){
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
    }finally{ if(mounted) setState(()=>_linking=false); }
  }

  @override Widget build(BuildContext context){
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(backgroundColor: Colors.white, elevation:0, title: const Text('Mon Médecin Traitant', style: TextStyle(fontWeight:FontWeight.w800, fontSize:18)), leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: ()=>Navigator.pop(context))),
      body: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Form(key:_formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: const Color(0xFFDBEAFE), borderRadius: BorderRadius.circular(16)), child: Row(children: [Container(padding: const EdgeInsets.all(10), decoration: const BoxDecoration(color:Colors.white, shape:BoxShape.circle), child: const Icon(Icons.link, color:Color(0xFF0B63F6))), const SizedBox(width:12), const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Liaison par THIX ID', style: TextStyle(fontWeight:FontWeight.w700)), SizedBox(height:2), Text('Saisissez le THIX ID affiché chez votre médecin', style: TextStyle(fontSize:12, color:Color(0xFF64748B)))]))]) ),
        const SizedBox(height:24),
        TextFormField(controller:_ctrl, textCapitalization: TextCapitalization.characters, decoration: InputDecoration(labelText:'THIX ID du médecin', hintText:'THIX-DOC001', prefixIcon: const Icon(Icons.fingerprint), suffixIcon: IconButton(icon: const Icon(Icons.qr_code_scanner), onPressed: (){ ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Scanner QR bientôt - utilise mobile_scanner'))); }), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)), filled:true, fillColor: Colors.white), validator: (v){ if(v==null||v.trim().isEmpty) return 'THIX ID requis'; if(!ThixIdValidator.isValidFormat(v)) return 'Format invalide'; return null; }, onFieldSubmitted: (_)=>_search()),
        const SizedBox(height:16),
        SizedBox(height:48, child: ElevatedButton(onPressed:_searching?null:_search, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0B63F6), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: _searching? const SizedBox(width:20,height:20,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white)): const Text('Vérifier le THIX ID', style: TextStyle(fontWeight:FontWeight.w700)))),
        if(_err!=null)...[const SizedBox(height:16), Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(12)), child: Row(children: [const Icon(Icons.error_outline, color:Colors.red, size:20), const SizedBox(width:8), Expanded(child: Text(_err!, style: const TextStyle(color:Colors.red, fontSize:13)))]))],
        if(_found!=null)...[const SizedBox(height:24), Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color:Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color:const Color(0xFFE2E8F0)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius:12)]), child: Column(children: [Row(children: [CircleAvatar(radius:28, backgroundColor: const Color(0xFFDBEAFE), backgroundImage: _found!.hasAvatar? NetworkImage(_found!.avatarUrl!):null, child:!_found!.hasAvatar? Text(_found!.initials, style: const TextStyle(fontWeight:FontWeight.w800, color:Color(0xFF0B63F6))):null), const SizedBox(width:14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Expanded(child: Text(_found!.fullName, style: const TextStyle(fontWeight:FontWeight.w800, fontSize:16))), if(_found!.isVerified) Container(padding: const EdgeInsets.symmetric(horizontal:6,vertical:2), decoration:BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius:BorderRadius.circular(20)), child: const Row(mainAxisSize:MainAxisSize.min, children:[Icon(Icons.verified, size:12, color:Color(0xFF16A34A)), SizedBox(width:2), Text('Vérifié', style: TextStyle(fontSize:10, fontWeight:FontWeight.w700, color:Color(0xFF16A34A)))]))]), Text(_found!.displaySpeciality, style: const TextStyle(color:Color(0xFF64748B), fontSize:13)), Text(_found!.thixId, style: const TextStyle(fontFamily:'monospace', fontSize:11, color:Color(0xFF94A3B8)))]))]), const SizedBox(height:20), SizedBox(width:double.infinity, height:48, child: ElevatedButton.icon(onPressed:_linking?null:_link, icon: _linking? const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white)): const Icon(Icons.link), label: Text(_linking?'Liaison...':'Confirmer comme médecin traitant'), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))) )]))]
      ]))),
    );
  }
}
