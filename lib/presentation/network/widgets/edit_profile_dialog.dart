import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditProfileDialog extends ConsumerStatefulWidget {
  final String userId;
  final String currentName;
  final String? currentTitle;
  final String? currentBio;
  final String? currentAvatarUrl;
  final List<String> currentSkills;
  const EditProfileDialog({super.key, required this.userId, required this.currentName, this.currentTitle, this.currentBio, this.currentAvatarUrl, this.currentSkills = const []});
  @override ConsumerState<EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends ConsumerState<EditProfileDialog> {
  late TextEditingController _name, _title, _bio;
  final List<TextEditingController> _skills = [];
  Uint8List? _avatarBytes;
  String _ext = 'jpg';
  bool _saving = false;

  @override void initState() {
    super.initState();
    _name = TextEditingController(text: widget.currentName);
    _title = TextEditingController(text: widget.currentTitle?? '');
    _bio = TextEditingController(text: widget.currentBio?? '');
    for (var s in widget.currentSkills) { _skills.add(TextEditingController(text: s)); }
    if (_skills.isEmpty) _skills.add(TextEditingController());
  }
  @override void dispose() { _name.dispose(); _title.dispose(); _bio.dispose(); for(final c in _skills) c.dispose(); super.dispose(); }

  Future<void> _pick() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    if (r==null || r.files.isEmpty) return;
    final f = r.files.first;
    if ((f.bytes?.length?? f.size) > 5*1024*1024) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Max 5MB'), backgroundColor: Colors.red));
      return;
    }
    setState(() { _avatarBytes = f.bytes; _ext = f.extension?? 'jpg'; });
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Nom requis'), backgroundColor: Colors.red)); return; }
    final skills = _skills.map((c)=> c.text.trim()).where((s)=> s.isNotEmpty).toList();
    if (skills.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('1 compétence min'), backgroundColor: Colors.red)); return; }

    setState(()=> _saving = true);
    final supabase = Supabase.instance.client;
    final messenger = ScaffoldMessenger.of(context);
    try {
      String? avatarUrl = widget.currentAvatarUrl;
      if (_avatarBytes!= null) {
        final path = '${widget.userId}/avatar_${DateTime.now().millisecondsSinceEpoch}.$_ext';
        await supabase.storage.from('avatars').uploadBinary(path, _avatarBytes!, fileOptions: FileOptions(contentType: 'image/$_ext', upsert: true));
        avatarUrl = supabase.storage.from('avatars').getPublicUrl(path);
      }

      await supabase.from('profiles').update({
        'display_name': name,
        'profession': _title.text.trim(),
        'bio': _bio.text.trim(),
        'skills': skills, // si ton champ est jsonb, supabase gère List<String>
        'photo_url': avatarUrl,
        'avatar_url': avatarUrl,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', widget.userId);

      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Profil mis à jour!'), backgroundColor: Colors.green));
      Navigator.pop(context, {'name': name, 'avatar_url': avatarUrl, 'skills': skills});
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
    } finally {
      if(mounted) setState(()=> _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasAvatar = widget.currentAvatarUrl!=null || _avatarBytes!=null;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: MediaQuery.of(context).size.width*0.9,
        constraints: BoxConstraints(maxHeight: 650),
        padding: EdgeInsets.all(20),
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Modifier mon profil', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), IconButton(icon: Icon(Icons.close), onPressed: ()=> Navigator.pop(context))]),
          SizedBox(height: 16),
          Expanded(child: SingleChildScrollView(child: Column(children: [
            Stack(children: [
              Container(width: 100, height: 100, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Color(0xFFD4AF37), width: 2)),
                child: ClipOval(child: _avatarBytes!=null? Image.memory(_avatarBytes!, fit: BoxFit.cover) : widget.currentAvatarUrl!=null? Image.network(widget.currentAvatarUrl!, fit: BoxFit.cover, errorBuilder: (_,__,___)=> Icon(Icons.person, size: 50)) : Icon(Icons.person, size: 50))),
              Positioned(bottom: 0, right: 0, child: GestureDetector(onTap: _pick, child: Container(padding: EdgeInsets.all(6), decoration: BoxDecoration(color: Color(0xFFD4AF37), shape: BoxShape.circle), child: Icon(Icons.camera_alt, size: 18, color: Color(0xFF0B1B3D))))),
              if(hasAvatar) Positioned(bottom: 0, left: 0, child: GestureDetector(onTap: ()=> setState(()=> _avatarBytes=null), child: Container(padding: EdgeInsets.all(4), decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle), child: Icon(Icons.delete, size: 14, color: Colors.white)))),
            ]),
            SizedBox(height: 24),
            TextField(controller: _name, decoration: InputDecoration(labelText: 'Nom complet *', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person_outline))),
            SizedBox(height: 16),
            TextField(controller: _title, decoration: InputDecoration(labelText: 'Titre', border: OutlineInputBorder(), prefixIcon: Icon(Icons.work_outline))),
            SizedBox(height: 16),
            TextField(controller: _bio, maxLines: 3, decoration: InputDecoration(labelText: 'Bio', border: OutlineInputBorder(), prefixIcon: Icon(Icons.description_outlined))),
            SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Compétences', style: TextStyle(fontWeight: FontWeight.bold)), TextButton.icon(onPressed: ()=> setState(()=> _skills.length<10? _skills.add(TextEditingController()) : null), icon: Icon(Icons.add, size:16), label: Text('Ajouter'))]),
           ...List.generate(_skills.length, (i)=> Padding(padding: EdgeInsets.only(bottom: 8), child: Row(children: [Expanded(child: TextField(controller: _skills[i], decoration: InputDecoration(hintText: 'Ex: Flutter', border: OutlineInputBorder(), isDense: true))), IconButton(icon: Icon(Icons.close, size: 18), onPressed: ()=> setState(()=> _skills.removeAt(i)))]))),
          ]))),
          SizedBox(height: 16),
          ElevatedButton(onPressed: _saving? null : _save, style: ElevatedButton.styleFrom(backgroundColor: Color(0xFFD4AF37), foregroundColor: Color(0xFF0B1B3D), padding: EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))), child: _saving? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5)) : Text('ENREGISTRER', style: TextStyle(fontWeight: FontWeight.bold))),
        ]),
      ),
    );
  }
}
