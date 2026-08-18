// lib/presentation/thix_sante/patient/screens/assistant_ia_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AssistantIAPage extends StatefulWidget {
  const AssistantIAPage({super.key});
  @override State<AssistantIAPage> createState() => _AssistantIAPageState();
}

class _AssistantIAPageState extends State<AssistantIAPage> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  final _db = Supabase.instance.client;
  String? _convId;
  bool _loading = false;
  List<Map<String,String>> _messages = [
    {'role':'ia','content':'Bonjour 👋 Je suis THIX IA Santé. Comment puis-je vous aider?'}
  ];
  String _dossierTxt = 'THIX ID actif';

  @override
  void initState(){ super.initState(); _initSafe(); }

  Future<void> _initSafe() async {
    try{
      final uid = _db.auth.currentUser!.id;
      // dossier ne doit jamais bloquer le chat
      try{
        final c = await _db.from('health_links').select('id').eq('patient_id', uid);
        final e = await _db.from('health_records').select('id').eq('patient_id', uid);
        setState(()=> _dossierTxt = 'THIX ID actif • ${(c as List).length} cons. • ${(e as List).length} examens');
      } catch(_){}

      // recup ou cree conversation
      final existing = await _db.from('ai_conversations').select('id').eq('patient_id', uid).order('created_at', ascending:false).limit(1).maybeSingle();
      if(existing!=null){
        _convId = existing['id'];
        final msgs = await _db.from('ai_messages').select('role, content').eq('conversation_id', _convId!).order('created_at');
        if((msgs as List).isNotEmpty){
          setState(()=> _messages = List<Map<String,String>>.from(msgs.map((m)=> {'role': m['role'] as String, 'content': m['content'] as String})));
        }
      }
    } catch(e){
      debugPrint('init error $e');
    }
  }

  Future<void> _ensureConv() async {
    if(_convId!=null) return;
    final uid = _db.auth.currentUser!.id;
    final conv = await _db.from('ai_conversations').insert({'patient_id': uid, 'title': 'Chat ${DateTime.now().day}/${DateTime.now().month}'}).select('id').single();
    _convId = conv['id'];
  }

  Future<void> _send(String text) async {
    if(text.trim().isEmpty) return;
    FocusScope.of(context).unfocus();
    setState((){ _messages.add({'role':'user','content':text}); _loading=true; _ctrl.clear(); });
    _toBottom();
    try{
      await _ensureConv();
      final res = await _db.functions.invoke('thix-ia-chat', body: {'conversation_id': _convId, 'message': text});
      if(res.data==null) throw Exception(res.data);
      final reply = res.data['reply']?? res.data['error']?? 'Pas de réponse';
      setState(()=> _messages.add({'role':'ia','content': reply.toString()}));
    } catch(e){
      setState(()=> _messages.add({'role':'ia','content': 'Erreur: $e - Vérifie les secrets MISTRAL_API_KEY dans Supabase'}));
    }
    setState(()=> _loading=false);
    _toBottom();
  }

  void _toBottom()=> WidgetsBinding.instance.addPostFrameCallback((_){
    if(_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent+200, duration: const Duration(milliseconds:300), curve: Curves.easeOut);
  });

  @override
  Widget build(BuildContext context){
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white, elevation:0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)), onPressed: ()=> Navigator.pop(context)),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
          const Text('THIX IA Santé', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w800, fontSize:15)),
          Text(_dossierTxt, style: const TextStyle(color: Color(0xFF22C55E), fontSize:10, fontWeight: FontWeight.w600)),
        ]),
      ),
      body: Column(children:[
        Container(color: const Color(0xFFFEF9C3), padding: const EdgeInsets.all(8), child: const Text('IA éducative uniquement. Ne remplace pas un avis médical.', style: TextStyle(fontSize:10))),
        Expanded(child: ListView.separated(
          controller: _scroll,
          padding: const EdgeInsets.all(16),
          itemCount: _messages.length + (_loading?1:0),
          separatorBuilder: (_,__)=> const SizedBox(height:10),
          itemBuilder: (c,i){
            if(_loading && i==_messages.length) return const Align(alignment: Alignment.centerLeft, child: Text('THIX IA écrit...', style: TextStyle(fontSize:11, color: Colors.grey)));
            final m = _messages[i];
            final isUser = m['role']=='user';
            return Align(
              alignment: isUser? Alignment.centerRight: Alignment.centerLeft,
              child: Container(
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width*0.78),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: isUser? const Color(0xFF2563EB): Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE2E8F0))),
                child: Text(m['content']!, style: TextStyle(fontSize:13, color: isUser? Colors.white: const Color(0xFF0F172A))),
              ),
            );
          },
        )),
        SafeArea(child: Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(12,8,12,8),
          child: Row(children:[
            Expanded(child: TextField(controller: _ctrl, minLines:1, maxLines:4, onSubmitted: _send, decoration: InputDecoration(hintText: 'Posez une question santé...', filled:true, fillColor: const Color(0xFFF1F5F9), border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal:16, vertical:10)))),
            const SizedBox(width:8),
            GestureDetector(
              onTap: _loading? null: ()=> _send(_ctrl.text),
              child: Container(width:48,height:48, decoration: BoxDecoration(color: _loading? Colors.grey: const Color(0xFF2563EB), shape: BoxShape.circle), child: const Icon(Icons.send_rounded, color: Colors.white, size:20)),
            ),
          ]),
        )),
      ]),
    );
  }
}
