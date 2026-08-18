import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';

class ReelsPage extends ConsumerStatefulWidget {
  const ReelsPage({super.key});
  @override ConsumerState<ReelsPage> createState() => _ReelsPageState();
}

class _ReelsPageState extends ConsumerState<ReelsPage> {
  List<Map<String, dynamic>> _reels = [];
  bool _loading = true;
  final _pageCtrl = PageController();

  @override void initState(){ super.initState(); _load(); }
  Future<void> _load() async {
    try{
      final res = await Supabase.instance.client.from('reels').select('id, video_url, caption, likes_count, user_id, created_at, profiles(display_name, photo_url, avatar_url)').eq('is_active', true).order('created_at', ascending: false).limit(50);
      if(mounted) setState(()=> {_reels = (res as List).cast<Map<String,dynamic>>(), _loading=false});
    }catch(e){
      // fallback sur network_posts video
      try{
        final res2 = await Supabase.instance.client.from('network_posts').select('id, image_url, video_url, content, user_id, profiles(display_name, photo_url)').not('video_url', 'is', null).order('created_at', ascending: false).limit(30);
        if(mounted) setState(()=> {_reels = (res2 as List).map((m)=> {'id': m['id'], 'video_url': m['video_url']?? m['image_url'], 'caption': m['content'], 'profiles': m['profiles']}).toList(), _loading=false});
      }catch(_){ if(mounted) setState(()=> _loading=false); }
    }
  }
  @override void dispose(){ _pageCtrl.dispose(); super.dispose(); }

  @override Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _loading? Center(child: CircularProgressIndicator(color: Colors.white)) : _reels.isEmpty? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.slow_motion_video, size: 80, color: Colors.white54), SizedBox(height: 16), Text('Aucun Reel', style: TextStyle(color: Colors.white54))])) : Stack(children: [
        PageView.builder(controller: _pageCtrl, scrollDirection: Axis.vertical, itemCount: _reels.length, itemBuilder: (_,i)=> _ReelItem(reel: _reels[i])),
        SafeArea(child: Padding(padding: EdgeInsets.all(16), child: Row(children: [Text('Reels', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)), Spacer(), IconButton(icon: Icon(Icons.camera_alt, color: Colors.white), onPressed: (){})]))),
      ]),
    );
  }
}

class _ReelItem extends StatefulWidget {
  final Map<String,dynamic> reel;
  const _ReelItem({required this.reel});
  @override State<_ReelItem> createState()=> _ReelItemState();
}
class _ReelItemState extends State<_ReelItem> {
  VideoPlayerController? _ctrl;
  bool _liked = false;

  @override void initState(){
    super.initState();
    final url = widget.reel['video_url']?? '';
    if(url.isNotEmpty){
      _ctrl = VideoPlayerController.networkUrl(Uri.parse(url))..initialize().then((_) { if(mounted){ setState((){}); _ctrl!.setLooping(true); _ctrl!.play(); }});
    }
  }
  @override void dispose(){ _ctrl?.dispose(); super.dispose(); }

  @override Widget build(BuildContext context) {
    final profile = widget.reel['profiles'] as Map?;
    final name = profile?['display_name']?? 'User';
    final avatar = profile?['photo_url']?? profile?['avatar_url'];
    final caption = widget.reel['caption']?? widget.reel['content']?? '';

    return Stack(children: [
      if(_ctrl!=null && _ctrl!.value.isInitialized) SizedBox.expand(child: FittedBox(fit: BoxFit.cover, child: SizedBox(width: _ctrl!.value.size.width, height: _ctrl!.value.size.height, child: VideoPlayer(_ctrl!)))) else Container(color: Colors.black, child: Center(child: CircularProgressIndicator(color: Colors.white))),
      Positioned.fill(child: GestureDetector(onTap: ()=> _ctrl?.value.isPlaying==true? _ctrl?.pause() : _ctrl?.play())),
      Positioned(bottom: 20, left: 16, right: 70, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [CircleAvatar(radius: 16, child: ClipOval(child: avatar!=null? Image.network(avatar, width: 32, height: 32, fit: BoxFit.cover, errorBuilder: (_,__,___)=> Icon(Icons.person, size: 16)) : Icon(Icons.person, size: 16))), SizedBox(width: 8), Text('@$name', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))]),
        SizedBox(height: 8),
        Text(caption, style: TextStyle(color: Colors.white, fontSize: 14), maxLines: 2, overflow: TextOverflow.ellipsis),
      ])),
      Positioned(bottom: 20, right: 12, child: Column(children: [
        IconButton(icon: Icon(_liked? Icons.favorite : Icons.favorite_border, color: _liked? Colors.red : Colors.white, size: 30), onPressed: ()=> setState(()=> _liked=!_liked)),
        Text('${(widget.reel['likes_count']?? 0) + (_liked?1:0)}', style: TextStyle(color: Colors.white, fontSize: 12)),
        SizedBox(height: 16),
        IconButton(icon: Icon(Icons.comment_outlined, color: Colors.white, size: 28), onPressed: (){}),
        SizedBox(height: 16),
        IconButton(icon: Icon(Icons.share, color: Colors.white, size: 28), onPressed: (){}),
      ])),
    ]);
  }
}
