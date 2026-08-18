import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/chat/connection_service.dart';

class _C {
  static const bg = Color(0xFF050508);
  static const surface = Color(0xFF0C0C12);
  static const surfaceAlt = Color(0xFF111118);
  static const cardBorder = Color(0x14FFFFFF);
  static const violet = Color(0xFF7C5CFF);
  static const white = Colors.white;
  static const textMuted = Color(0x66FFFFFF);
  static const textSecondary = Color(0x99FFFFFF);
  static const red = Color(0xFFFF0A54);
  static const green = Color(0xFF10B981);
}

class ConnectionRequestsState {
  final List<ConnectionRequest> items;
  final bool loading;
  final bool loadingMore;
  final bool hasMore;
  const ConnectionRequestsState({this.items = const [], this.loading = true, this.loadingMore = false, this.hasMore = true});
  ConnectionRequestsState copyWith({List<ConnectionRequest>? items, bool? loading, bool? loadingMore, bool? hasMore}) =>
    ConnectionRequestsState(items: items?? this.items, loading: loading?? this.loading, loadingMore: loadingMore?? this.loadingMore, hasMore: hasMore?? this.hasMore);
}

class ConnectionRequestsNotifier extends StateNotifier<ConnectionRequestsState> {
  final ConnectionService _svc;
  static const _limit = 20;
  ConnectionRequestsNotifier(this._svc) : super(const ConnectionRequestsState()) { loadInitial(); }

  Future<void> loadInitial() async {
    state = state.copyWith(loading: true);
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) { state = state.copyWith(loading: false); return; }
    try {
      final reqs = await _svc.getPendingRequests(uid, limit: _limit, offset: 0);
      state = ConnectionRequestsState(items: reqs, loading: false, hasMore: reqs.length == _limit);
    } catch (_) { state = state.copyWith(loading: false); }
  }

  Future<void> loadMore() async {
    if (state.loadingMore ||!state.hasMore) return;
    state = state.copyWith(loadingMore: true);
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) { state = state.copyWith(loadingMore: false); return; }
    try {
      final reqs = await _svc.getPendingRequests(uid, limit: _limit, offset: state.items.length);
      state = state.copyWith(items: [...state.items,...reqs], hasMore: reqs.length == _limit, loadingMore: false);
    } catch (_) { state = state.copyWith(loadingMore: false); }
  }

  Future<void> accept(String id) async { await _svc.acceptRequest(id); await loadInitial(); }
  Future<void> reject(String id) async { await _svc.rejectRequest(id); await loadInitial(); }
}

final connectionRequestsProvider = StateNotifierProvider<ConnectionRequestsNotifier, ConnectionRequestsState>((ref) {
  return ConnectionRequestsNotifier(ConnectionService());
});

class ConnectionRequestsPage extends ConsumerStatefulWidget {
  const ConnectionRequestsPage({super.key});
  @override ConsumerState<ConnectionRequestsPage> createState() => _ConnectionRequestsPageState();
}

class _ConnectionRequestsPageState extends ConsumerState<ConnectionRequestsPage> {
  final _scroll = ScrollController();

  @override void initState() {
    super.initState();
    _scroll.addListener(() { if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 200) ref.read(connectionRequestsProvider.notifier).loadMore(); });
  }
  @override void dispose() { _scroll.dispose(); super.dispose(); }

  Future<void> _confirmReject(String id) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: _C.surface, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color:_C.cardBorder)),
      title: const Text('Refuser la demande?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize:13)),
      content: const Text('Êtes-vous sûr de vouloir refuser cette invitation?', style: TextStyle(color:_C.textSecondary, fontSize:12)),
      actions: [
        TextButton(onPressed: ()=> Navigator.pop(ctx,false), child: const Text('Annuler',style: TextStyle(color:_C.textMuted))),
        ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor:_C.red, foregroundColor:Colors.white), onPressed:()=> Navigator.pop(ctx,true), child: const Text('Oui, refuser',style:TextStyle(fontSize:11,fontWeight:FontWeight.w800))),
      ],
    ));
    if (ok==true) {
      try { await ref.read(connectionRequestsProvider.notifier).reject(id); if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Demande refusée'),backgroundColor:Colors.orange)); }
      catch(e){ if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Erreur: $e'),backgroundColor:_C.red)); }
    }
  }

  Future<void> _accept(String id) async {
    try { await ref.read(connectionRequestsProvider.notifier).accept(id); if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Connexion acceptée'),backgroundColor:_C.green)); }
    catch(e){ if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Erreur: $e'),backgroundColor:_C.red)); }
  }

  @override Widget build(BuildContext context) {
    final state = ref.watch(connectionRequestsProvider);

    return Scaffold(
      backgroundColor: _C.bg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: ClipRRect(child: BackdropFilter(filter: ImageFilter.blur(sigmaX:20,sigmaY:20), child: AppBar(backgroundColor:_C.bg.withOpacity(0.85), elevation:0, centerTitle:true, leading: IconButton(icon: const Icon(Icons.arrow_back_rounded,color:Colors.white,size:18), onPressed:()=> Navigator.pop(context)), title: const Text('Demandes reçues',style:TextStyle(color:Colors.white,fontSize:13,fontWeight:FontWeight.w800))))),
      ),
      body: state.loading? const Center(child: CircularProgressIndicator(color:_C.violet,strokeWidth:2)) : state.items.isEmpty? const Center(child: Text('Aucune demande en attente',style:TextStyle(color:_C.textMuted,fontSize:11))) : RefreshIndicator(
        color: Colors.white, backgroundColor: _C.surface,
        onRefresh: () async => ref.read(connectionRequestsProvider.notifier).loadInitial(),
        child: ListView.builder(
          controller: _scroll,
          padding: const EdgeInsets.all(12),
          itemCount: state.items.length + (state.hasMore?1:0),
          itemBuilder: (ctx,i){
            if(i==state.items.length) return const Padding(padding:EdgeInsets.all(20),child:Center(child:CircularProgressIndicator(color:_C.violet,strokeWidth:2)));
            final req = state.items[i];
            final sender = req.sender;
            final name = sender?['display_name']?? sender?['username']?? 'Inconnu';
            return Container(
              margin: const EdgeInsets.only(bottom:10),
              padding: const EdgeInsets.symmetric(horizontal:12,vertical:10),
              decoration: BoxDecoration(color:_C.surface,borderRadius:BorderRadius.circular(14),border:Border.all(color:_C.cardBorder)),
              child: Row(children:[
                CircleAvatar(radius:18,backgroundColor:_C.violet.withOpacity(0.14),child:Text(name[0].toUpperCase(),style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w800,fontSize:12))),
                const SizedBox(width:10),
                Expanded(child: Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(name,style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w700,fontSize:12)), const SizedBox(height:2), Text(req.message??'Souhaite vous contacter',maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(color:_C.textMuted,fontSize:10))])),
                IconButton(icon: const Icon(Icons.check_rounded,color:_C.green,size:18), onPressed:()=> _accept(req.id)),
                IconButton(icon: const Icon(Icons.close_rounded,color:_C.textMuted,size:18), onPressed:()=> _confirmReject(req.id)),
              ]),
            );
          },
        ),
      ),
    );
  }
}
