// lib/presentation/thix_weeding/pages/staff/parametres/wedding_info_form_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

class WeddingInfoFormPage extends StatefulWidget {
  final String weddingId;
  const WeddingInfoFormPage({super.key, required this.weddingId});
  @override State<WeddingInfoFormPage> createState()=> _WeddingInfoFormPageState();
}

class _WeddingInfoFormPageState extends State<WeddingInfoFormPage> {
  final _form = GlobalKey<FormState>();
  final _bride = TextEditingController();
  final _groom = TextEditingController();
  final _venue = TextEditingController();
  DateTime? _date;
  bool _loading=true, _saving=false;

  @override void initState(){ super.initState(); _load(); }
  Future<void> _load() async {
    final w = await Supabase.instance.client.from('thix_weeding_weddings').select().eq('id', widget.weddingId).single();
    setState((){ _bride.text=w['bride_name']??''; _groom.text=w['groom_name']??''; _venue.text=w['venue']??''; _date=w['wedding_date']!=null?DateTime.parse(w['wedding_date']):null; _loading=false; });
  }

  Future<void> _save() async {
    if(!_form.currentState!.validate()) return;
    setState(()=> _saving=true);
    try{
      await Supabase.instance.client.from('thix_weeding_weddings').update({
        'bride_name': _bride.text.trim(),
        'groom_name': _groom.text.trim(),
        'venue': _venue.text.trim(),
        'wedding_date': _date?.toIso8601String().split('T')[0],
      }).eq('id', widget.weddingId);
      if(mounted){ ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mariage mis à jour'))); context.pop(); }
    }catch(e){ ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur $e'))); }
    finally{ if(mounted) setState(()=> _saving=false); }
  }

  @override Widget build(BuildContext context)=> Scaffold(appBar: AppBar(title: const Text('Infos mariage')), body: _loading? const Center(child: CircularProgressIndicator()): Form(key: _form, child: ListView(padding: const EdgeInsets.all(16), children: [
    TextFormField(controller: _bride, decoration: const InputDecoration(labelText:'Nom de la mariée *'), validator: (v)=> v!.isEmpty?'Requis':null),
    const SizedBox(height:12),
    TextFormField(controller: _groom, decoration: const InputDecoration(labelText:'Nom du marié *'), validator: (v)=> v!.isEmpty?'Requis':null),
    const SizedBox(height:12),
    ListTile(leading: const Icon(Icons.calendar_today), title: Text(_date==null?'Choisir date mariage':'Date: ${_date!.day}/${_date!.month}/${_date!.year}'), onTap: () async {
      final picked = await showDatePicker(context: context, initialDate: _date??DateTime.now(), firstDate: DateTime.now().subtract(const Duration(days:30)), lastDate: DateTime.now().add(const Duration(days:720)));
      if(picked!=null) setState(()=> _date=picked);
    }),
    const SizedBox(height:12),
    TextFormField(controller: _venue, decoration: const InputDecoration(labelText:'Lieu / Salle'), maxLines:2),
    const SizedBox(height:24),
    FilledButton(onPressed: _saving?null:_save, child: _saving? const CircularProgressIndicator(): const Text('Enregistrer modifications')),
    const SizedBox(height:8),
    Text('Wedding ID: ${widget.weddingId}', style: const TextStyle(fontSize:10, color: Colors.grey)),
  ])));
}
