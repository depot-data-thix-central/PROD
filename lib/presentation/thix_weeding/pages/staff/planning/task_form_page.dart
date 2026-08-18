// lib/presentation/thix_weeding/pages/staff/planning/task_form_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

class TaskFormPage extends StatefulWidget {
  final String weddingId; final String? editTaskId;
  const TaskFormPage({super.key, required this.weddingId, this.editTaskId});
  @override State<TaskFormPage> createState()=> _TaskFormPageState();
}

class _TaskFormPageState extends State<TaskFormPage> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _location = TextEditingController();
  DateTime _date = DateTime.now();
  TimeOfDay _time = TimeOfDay.now();
  String _status = 'todo';
  String _priority = 'medium';
  bool _loading = false;

  @override void initState(){ super.initState(); if(widget.editTaskId!=null) _load(); }
  Future<void> _load() async {
    final t = await Supabase.instance.client.from('thix_weeding_planning').select().eq('id', widget.editTaskId!).single();
    setState((){
      _title.text=t['title']; _desc.text=t['description']??''; _location.text=t['location']??'';
      _date=DateTime.parse(t['date']); _status=t['status']; _priority=t['priority'];
      if(t['time']!=null){ final parts=t['time'].toString().split(':'); _time=TimeOfDay(hour:int.parse(parts[0]), minute:int.parse(parts[1])); }
    });
  }

  Future<void> _save() async {
    if(!_form.currentState!.validate()) return;
    setState(()=> _loading=true);
    try{
      final data = {
        'wedding_id': widget.weddingId,
        'title': _title.text.trim(),
        'description': _desc.text.trim(),
        'date': _date.toIso8601String().split('T')[0],
        'time': '${_time.hour.toString().padLeft(2,'0')}:${_time.minute.toString().padLeft(2,'0')}',
        'location': _location.text.trim(),
        'status': _status,
        'priority': _priority,
      };
      if(widget.editTaskId==null){
        final inserted = await Supabase.instance.client.from('thix_weeding_planning').insert(data).select().single();
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Tâche créée ID: ${inserted['id']}')));
      } else {
        await Supabase.instance.client.from('thix_weeding_planning').update(data).eq('id', widget.editTaskId!);
      }
      if(mounted) context.pop();
    }catch(e){ ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur $e'))); }
    finally{ if(mounted) setState(()=> _loading=false); }
  }

  @override Widget build(BuildContext context)=> Scaffold(appBar: AppBar(title: Text(widget.editTaskId==null?'Nouvelle tâche':'Modifier tâche')), body: Form(key: _form, child: ListView(padding: const EdgeInsets.all(16), children: [
    TextFormField(controller: _title, decoration: const InputDecoration(labelText:'Titre * ex: Dégustation traiteur'), validator: (v)=> v!.isEmpty?'Requis':null),
    const SizedBox(height:12),
    TextFormField(controller: _desc, decoration: const InputDecoration(labelText:'Description'), maxLines: 3),
    const SizedBox(height:12),
    Row(children: [
      Expanded(child: ListTile(title: Text('Date: ${_date.day}/${_date.month}/${_date.year}'), leading: const Icon(Icons.calendar_today), onTap: () async {
        final picked = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime.now().subtract(const Duration(days:30)), lastDate: DateTime.now().add(const Duration(days:365)));
        if(picked!=null) setState(()=> _date=picked);
      })),
      Expanded(child: ListTile(title: Text('Heure: ${_time.format(context)}'), leading: const Icon(Icons.access_time), onTap: () async {
        final picked = await showTimePicker(context: context, initialTime: _time);
        if(picked!=null) setState(()=> _time=picked);
      })),
    ]),
    TextFormField(controller: _location, decoration: const InputDecoration(labelText:'Lieu')),
    const SizedBox(height:12),
    DropdownButtonFormField(value: _status, decoration: const InputDecoration(labelText:'Statut'), items: const [DropdownMenuItem(value:'todo', child:Text('À faire')), DropdownMenuItem(value:'in_progress', child:Text('En cours')), DropdownMenuItem(value:'done', child:Text('Terminée'))], onChanged: (v)=> setState(()=> _status=v!)),
    const SizedBox(height:12),
    DropdownButtonFormField(value: _priority, decoration: const InputDecoration(labelText:'Priorité'), items: const [DropdownMenuItem(value:'low', child:Text('Basse')), DropdownMenuItem(value:'medium', child:Text('Moyenne')), DropdownMenuItem(value:'high', child:Text('Haute'))], onChanged: (v)=> setState(()=> _priority=v!)),
    const SizedBox(height:24),
    FilledButton(onPressed: _loading?null:_save, child: _loading? const CircularProgressIndicator(): Text(widget.editTaskId==null?'Créer tâche':'Mettre à jour')),
  ])));
}
