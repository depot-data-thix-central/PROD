import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StoryViewerScreen extends StatefulWidget {
  final String storyId;
  final String? userId; // pour swiper toutes ses stories
  const StoryViewerScreen({super.key, required this.storyId, this.userId});
  @override State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen> {
  List<Map<String, dynamic>> _stories = [];
  int _current = 0;
  Timer? _timer;
  double _progress = 0;
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final supa = Supabase.instance.client;
    try {
      final first = await supa.from('stories').select('*, profiles(display_name, photo_url, avatar_url)').eq('id', widget.storyId).single();
      final uid = widget.userId ?? first['user_id'];
      final all = await supa.from('stories').select('*, profiles(display_name, photo_url, avatar_url)').eq('user_id', uid).eq('is_active', true).gt('expires_at', DateTime.now().toIso8601String()).order('created_at');
      final list = (all as List).cast<Map<String, dynamic>>();
      setState(() {
        _stories = list;
        _current = list.indexWhere((s)=> s['id']==widget.storyId);
        if(_current==-1) _current=0;
        _loading=false;
      });
      _startTimer();
      _markViewed();
    } catch(e){ setState(()=> _loading=false); }
  }

  void _startTimer(){
    _timer?.cancel();
    _progress=0;
    _timer = Timer.periodic(Duration(milliseconds: 50), (t){
      if(!mounted) return;
      setState(()=> _progress+=0.01);
      if(_progress>=1){ _next(); }
    });
  }

  void _markViewed(){
    final id = _stories[_current]['id'];
    Supabase.instance.client.from('stories').update({'is_viewed': true}).eq('id', id).then((_)=> null);
    // table story_views si tu veux compteur
    Supabase.instance.client.from('story_views').upsert({'story_id': id, 'viewer_id': Supabase.instance.client.auth.currentUser?.id}).then((_)=> null);
  }

  void _next(){
    if(_current < _stories.length-1){ setState(()=> _current++); _startTimer(); _markViewed(); }
    else { if(mounted) Navigator.pop(context); }
  }
  void _prev(){
    if(_current>0){ setState(()=> _current--); _startTimer(); _markViewed(); }
  }

  @override void dispose(){ _timer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if(_loading) return Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37))));
    if(_stories.isEmpty) return Scaffold(backgroundColor: Colors.black, appBar: AppBar(backgroundColor: Colors.transparent, leading: IconButton(icon: Icon(Icons.close, color: Colors.white), onPressed: ()=> Navigator.pop(context))), body: Center(child: Text('Story expirée', style: TextStyle(color: Colors.white))));

    final story = _stories[_current];
    final profile = story['profiles'] as Map?;
    final name = profile?['display_name'] ?? 'Utilisateur';
    final avatar = profile?['photo_url'] ?? profile?['avatar_url'];
    final mediaUrl = story['media_url'];
    final text = story['text'] ?? story['text_content'] ?? '';

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapDown: (d){
          final w = MediaQuery.of(context).size.width;
          if(d.globalPosition.dx < w/3) _prev(); else if(d.globalPosition.dx > w*2/3) _next();
        },
        child: Stack(children: [
          // MEDIA
          Positioned.fill(
            child: mediaUrl!=null && mediaUrl.isNotEmpty
            ? Image.network(mediaUrl, fit: BoxFit.contain, loadingBuilder: (c,w,p)=> p==null? w : Center(child: CircularProgressIndicator(color: Colors.white)), errorBuilder: (_,__,___)=> Center(child: Icon(Icons.broken_image, color: Colors.white, size: 60)))
            : Center(child: Padding(padding: EdgeInsets.all(24), child: Text(text, style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold), textAlign: TextAlign.center))),
          ),
          // PROGRESS
          SafeArea(child: Column(children: [
            SizedBox(height: 8),
            Row(children: List.generate(_stories.length, (i)=> Expanded(child: Container(margin: EdgeInsets.symmetric(horizontal: 2), height: 3, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(3)), child: Align(alignment: Alignment.centerLeft, child: FractionallySizedBox(widthFactor: i<_current? 1 : i==_current? _progress : 0, child: Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(3))))))))),
            SizedBox(height: 12),
            Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Row(children: [
              CircleAvatar(radius: 18, backgroundColor: Colors.grey, child: ClipOval(child: avatar!=null? Image.network(avatar, width: 36, height: 36, fit: BoxFit.cover, errorBuilder: (_,__,___)=> Icon(Icons.person, size: 18)) : Icon(Icons.person, size: 18))),
              SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)), Text('${DateTime.now().difference(DateTime.parse(story['created_at'])).inHours}h', style: TextStyle(color: Colors.white70, fontSize: 11))])),
              IconButton(icon: Icon(Icons.close, color: Colors.white), onPressed: ()=> Navigator.pop(context)),
            ])),
          ])),
          if(text.isNotEmpty && mediaUrl!=null) Positioned(bottom: 40, left: 16, right: 16, child: Text(text, style: TextStyle(color: Colors.white, fontSize: 16, shadows: [Shadow(blurRadius: 8, color: Colors.black)]), textAlign: TextAlign.center)),
        ]),
      ),
    );
  }
}
