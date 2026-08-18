import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/thix_sante_colors.dart';
import '../providers/appointment_provider.dart';
import 'package:intl/intl.dart';

class PrendreRdvPage extends ConsumerStatefulWidget {
  const PrendreRdvPage({super.key});
  @override ConsumerState<PrendreRdvPage> createState() => _PrendreRdvPageState();
}

class _PrendreRdvPageState extends ConsumerState<PrendreRdvPage> {
  String _type = 'Cabinet';
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  String? _doctorId;
  String _creneau = '09:00';
  final _motif = TextEditingController();
  final _creneaux = ['08:00','08:30','09:00','09:30','10:00','10:30','11:00','14:30','15:00','15:30','16:00'];

  Future<void> _pickDate() async {
    final d = await showDatePicker(context: context, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days:90)), initialDate: _date, selectableDayPredicate: (d)=>d.weekday!=7);
    if(d!=null) setState(()=>_date=d);
  }

  Future<void> _submit() async {
    if(_doctorId==null || _motif.text.trim().length<10) return;
    try{
      await ref.read(createAppointmentProvider.notifier).create(doctorId:_doctorId!, date:_date, creneau:_creneau, type:_type, motif:_motif.text.trim());
      if(!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('RDV créé, en attente de confirmation'), backgroundColor: Color(0xFF16A34A)));
      Navigator.pop(context);
    }catch(e){
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
    }
  }

  @override Widget build(BuildContext context){
    final doctors = ref.watch(linkedDoctorsProvider);
    final creating = ref.watch(createAppointmentProvider).isLoading;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Prendre RDV', style: TextStyle(fontWeight: FontWeight.w800)), backgroundColor: Colors.white, elevation:0, leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: ()=>Navigator.pop(context))),
      body: doctors.when(
        loading: ()=> const Center(child: CircularProgressIndicator()),
        error: (e,st)=> Center(child: Text('Erreur: $e')),
        data: (list){
          if(list.isEmpty){
            return const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('Aucun médecin lié.\nLiez un médecin dans "Consulter médecin" pour prendre RDV.', textAlign: TextAlign.center)));
          }
          _doctorId??= list.first['doctor_id'] as String;
          final taken = ref.watch(takenSlotsProvider((doctorId: _doctorId!, date: _date)));

          return ListView(padding: const EdgeInsets.all(16), children:[
            DropdownButtonFormField<String>(value: _doctorId, decoration: const InputDecoration(labelText:'Médecin', border: OutlineInputBorder()), items: list.map((e){ final d=e['doctors'] as Map<String,dynamic>; return DropdownMenuItem(value: e['doctor_id'] as String, child: Text(d['full_name']??'Docteur')); }).toList(), onChanged:(v)=>setState(()=>_doctorId=v)),
            const SizedBox(height:16),
            Wrap(spacing:8, children: ['Cabinet','Téléconsultation','Domicile'].map((t){ final sel=_type==t; return ChoiceChip(label: Text(t), selected: sel, onSelected: (_)=>setState(()=>_type=t)); }).toList()),
            const SizedBox(height:16),
            InkWell(onTap: _pickDate, child: InputDecorator(decoration: const InputDecoration(labelText:'Date', border: OutlineInputBorder(), suffixIcon: Icon(Icons.calendar_today)), child: Text(DateFormat('EEE dd MMMM yyyy','fr_FR').format(_date)))),
            const SizedBox(height:16),
            const Text('Créneau', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height:8),
            taken.when(
              loading: ()=> const LinearProgressIndicator(),
              error: (e,_)=> Text('Erreur créneaux: $e'),
              data: (busy){
                return GridView.builder(shrinkWrap:true, physics: const NeverScrollableScrollPhysics(), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:3, childAspectRatio:2.4, crossAxisSpacing:8, mainAxisSpacing:8), itemCount: _creneaux.length, itemBuilder: (_,i){
                  final c=_creneaux[i]; final isBusy=busy.contains(c); final sel=_creneau==c;
                  return ChoiceChip(label: SizedBox(width: double.infinity, child: Text(c, textAlign: TextAlign.center)), selected: sel, onSelected: isBusy?null:(v)=>setState(()=>_creneau=c), selectedColor: ThixSanteColors.primary, labelStyle: TextStyle(color: isBusy?Colors.grey:sel?Colors.white:Colors.black), disabledColor: const Color(0xFFF1F5F9));
                });
              }
            ),
            const SizedBox(height:16),
            TextField(controller:_motif, maxLines:3, onChanged:(_)=>setState((){}), decoration: const InputDecoration(labelText:'Motif (min 10 caractères)', border: OutlineInputBorder(), hintText:'Décris ton symptôme...')),
            const SizedBox(height:24),
            ElevatedButton(onPressed: (_motif.text.trim().length>=10 &&!creating && _doctorId!=null)?_submit:null, style: ElevatedButton.styleFrom(backgroundColor: ThixSanteColors.primary, minimumSize: const Size(double.infinity,50)), child: creating? const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white)): Text('Confirmer $_creneau')),
          ]);
        }
      ),
    );
  }
}
