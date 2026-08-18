import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GardiensConfigPage extends StatefulWidget {
  const GardiensConfigPage({super.key});
  @override State<GardiensConfigPage> createState() => _GardiensConfigPageState();
}

class _GardiensConfigPageState extends State<GardiensConfigPage> {
  final supabase = Supabase.instance.client;
  final searchCtrl = TextEditingController();
  List<Map<String,dynamic>> myGardiens = [];
  List<Map<String,dynamic>> searchResults = [];
  bool loading = false;

  @override void initState() {
    super.initState();
    loadMyGardiens();
  }

  Future<void> loadMyGardiens() async {
    final user = supabase.auth.currentUser;
    if(user==null) return;
    final res = await supabase.from('emergency_gardiens_config').select().eq('owner_user_id', user.id);
    setState(()=> myGardiens = List<Map<String,dynamic>>.from(res));
  }

  Future<void> searchUsers(String q) async {
    if(q.trim().length < 2) { setState(()=> searchResults = []); return; }
    setState(()=> loading = true);
    try {
      // Cherche dans tes profils publics THIX
      final res = await supabase.from('thix_profiles').select('user_id, full_name, thix_id, avatar_url')
       .ilike('full_name', '%$q%').limit(20);
      setState(()=> searchResults = List<Map<String,dynamic>>.from(res));
    } catch(e) {
      // fallback: app_users
      final res = await supabase.from('app_users').select('id, display_name, thix_id, photo_url')
       .ilike('display_name', '%$q%').limit(20);
      setState(()=> searchResults = List<Map<String,dynamic>>.from(res));
    }
    setState(()=> loading = false);
  }

  Future<void> addGardien(Map<String,dynamic> user) async {
    final owner = supabase.auth.currentUser!;
    final guardianId = user['user_id']?? user['id'];
    await supabase.from('emergency_gardiens_config').upsert({
      'owner_user_id': owner.id,
      'guardian_user_id': guardianId,
      'guardian_thix_id': user['thix_id']?? '',
      'guardian_name': user['full_name']?? user['display_name']?? 'Gardien',
      'guardian_avatar': user['avatar_url']?? user['photo_url']?? '',
    });
    loadMyGardiens();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${user['full_name']?? user['display_name']} ajouté comme gardien')));
  }

  Future<void> removeGardien(String id) async {
    await supabase.from('emergency_gardiens_config').delete().eq('id', id);
    loadMyGardiens();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0A0A0F),
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text('MES GARDIENS - SECOURS', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
      ),
      body: Column(
        children: [
          // Mes gardiens actuels
          if(myGardiens.isNotEmpty)
            Container(
              margin: EdgeInsets.all(12),
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Tes gardiens (${myGardiens.length}/5)', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Wrap(spacing: 8, children: myGardiens.map((g)=> Chip(
                  avatar: CircleAvatar(backgroundImage: g['guardian_avatar']?.isNotEmpty==true? NetworkImage(g['guardian_avatar']) : null),
                  label: Text(g['guardian_name']),
                  deleteIcon: Icon(Icons.close, size: 16),
                  onDeleted: ()=> removeGardien(g['id']),
                )).toList())
              ]),
            ),

          // Barre de recherche
          Padding(
            padding: EdgeInsets.all(12),
            child: TextField(
              controller: searchCtrl,
              style: TextStyle(color: Colors.white),
              onChanged: searchUsers,
              decoration: InputDecoration(
                hintText: 'Rechercher un contact THIX par nom ou THIX ID...',
                hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
                prefixIcon: Icon(Icons.search, color: Colors.white54),
                filled: true, fillColor: Color(0xFF1A1C25),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),
          if(loading) LinearProgressIndicator(color: Colors.red),

          // Résultats
          Expanded(child: ListView.builder(
            itemCount: searchResults.length,
            itemBuilder: (_, i) {
              final u = searchResults[i];
              final name = u['full_name']?? u['display_name']?? 'Inconnu';
              final thixId = u['thix_id']?? '';
              final avatar = u['avatar_url']?? u['photo_url']?? '';
              final alreadyAdded = myGardiens.any((g)=> g['guardian_user_id'] == (u['user_id']?? u['id']));
              return ListTile(
                leading: CircleAvatar(backgroundImage: avatar.isNotEmpty? NetworkImage(avatar) : null, child: avatar.isEmpty? Icon(Icons.person) : null),
                title: Text(name, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                subtitle: Text(thixId, style: TextStyle(color: Colors.white38, fontSize: 11)),
                trailing: alreadyAdded? Icon(Icons.check_circle, color: Colors.green) : ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: ()=> addGardien(u),
                  child: Text('AJOUTER', style: TextStyle(fontSize: 11)),
                ),
              );
            },
          )),

          // Info
          Container(
            padding: EdgeInsets.all(12),
            color: Color(0xFF1A1C25),
            child: Row(children: [
              Icon(Icons.info_outline, color: Colors.white38, size: 16),
              SizedBox(width: 8),
              Expanded(child: Text('Ils recevront ta position live + alerte sonore quand tu maintiens le bouton rouge 2s', style: TextStyle(color: Colors.white38, fontSize: 11)))
            ]),
          )
        ],
      ),
    );
  }
}
