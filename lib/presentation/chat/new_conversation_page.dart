// lib/presentation/chat/new_conversation_page.dart
import 'dart:async'; // ✅ Corrigé : i minuscule
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../nav.dart';
import '../../services/chat/chat_service.dart';
import '../../services/chat/connection_service.dart';

// ✅ Imports pour la certification
import 'package:thix_id/models/certification_tier.dart';
import 'package:thix_id/presentation/certification/widgets/certification_name_badge.dart';

// Nouvelle palette "Grandeur Entreprise" (Thème Clair)
class _C {
  static const bg = Colors.white;
  static const surface = Color(0xFFF8FAFC);
  static const border = Color(0xFFE2E8F0);
  static const primary = Color(0xFF0A66C2);
  static const primaryLight = Color(0xFFEFF6FF);
  static const textMain = Color(0xFF0F172A);
  static const textMuted = Color(0xFF64748B);
  static const green = Color(0xFF22C55E);
  static const red = Color(0xFFEF4444);
}

class NewConvState {
  final List<Map<String, dynamic>> results;
  final List<Map<String, dynamic>> selected;
  final Map<String, String> connStatus;
  final bool isLoading;
  final bool isCreating;
  final bool hasMore;
  final String query;
  final String groupName;

  const NewConvState({
    this.results = const [], 
    this.selected = const [], 
    this.connStatus = const {}, 
    this.isLoading = false, 
    this.isCreating = false, 
    this.hasMore = true, 
    this.query = '', 
    this.groupName = ''
  });

  NewConvState copyWith({
    List<Map<String, dynamic>>? results, 
    List<Map<String, dynamic>>? selected, 
    Map<String,String>? connStatus, 
    bool? isLoading, 
    bool? isCreating, 
    bool? hasMore, 
    String? query, 
    String? groupName
  }) {
    return NewConvState(
      results: results ?? this.results, 
      selected: selected ?? this.selected, 
      connStatus: connStatus ?? this.connStatus, 
      isLoading: isLoading ?? this.isLoading, 
      isCreating: isCreating ?? this.isCreating, 
      hasMore: hasMore ?? this.hasMore, 
      query: query ?? this.query, 
      groupName: groupName ?? this.groupName
    );
  }
}

class NewConvNotifier extends StateNotifier<NewConvState> {
  final SupabaseClient supabase;
  final ConnectionService connSvc;
  static const _limit = 25;
  int _offset = 0;
  Timer? _debounce;
  
  NewConvNotifier(this.supabase, this.connSvc) : super(const NewConvState());

  void setGroupName(String v) => state = state.copyWith(groupName: v);

  void search(String raw) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => _doSearch(raw.trim(), reset: true));
  }

  Future<void> _doSearch(String q, {bool reset = false}) async {
    if (q.isEmpty) { 
      state = state.copyWith(results: [], query: '', hasMore: true, isLoading: false); 
      return; 
    }
    
    if (reset) { 
      _offset = 0; 
      state = state.copyWith(query: q, isLoading: true, hasMore: true); 
    }
    
    try {
      // ✅ Ajout des champs de certification dans le select()
      final exact = await supabase.from('profiles').select('id, display_name, avatar_url, profession, thix_chat, certification_tier, certification_status, is_verified').ilike('thix_chat', '%$q%').range(_offset, _offset + 4);
      final names = await supabase.from('profiles').select('id, display_name, avatar_url, profession, thix_chat, certification_tier, certification_status, is_verified').ilike('display_name', '%$q%').range(_offset, _offset + _limit - 1);

      final seen = <String>{...state.selected.map((e) => e['id'] as String)};
      final merged = <Map<String,dynamic>>[];
      
      for (var r in [...exact, ...names]) {
        final id = r['id'] as String;
        if (!seen.contains(id)) { 
          seen.add(id); 
          merged.add(Map<String,dynamic>.from(r)); 
        }
      }
      
      await _loadStatus(merged);

      final finalList = reset ? merged : [...state.results, ...merged];
      final deduped = <String, Map<String,dynamic>>{};
      for (var e in finalList) deduped[e['id']] = e;

      state = state.copyWith(
        results: deduped.values.where((e) => !state.selected.any((s) => s['id'] == e['id'])).toList(), 
        isLoading: false, 
        hasMore: merged.length == _limit
      );
      _offset += _limit;
    } catch (_) { 
      state = state.copyWith(isLoading: false); 
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore || state.query.isEmpty) return;
    state = state.copyWith(isLoading: true);
    await _doSearch(state.query, reset: false);
  }

  Future<void> _loadStatus(List<Map<String,dynamic>> users) async {
    final cur = supabase.auth.currentUser?.id;
    if (cur == null) return;
    final map = Map<String,String>.from(state.connStatus);
    for (var u in users) {
      final id = u['id'] as String;
      if (id == cur || map.containsKey(id)) continue;
      map[id] = await connSvc.getStatusBetween(cur, id);
    }
    state = state.copyWith(connStatus: map);
  }

  void toggleSelect(Map<String,dynamic> user) {
    final exists = state.selected.any((s) => s['id'] == user['id']);
    List<Map<String,dynamic>> sel;
    List<Map<String,dynamic>> res = List.from(state.results);
    if (exists) {
      sel = state.selected.where((s) => s['id'] != user['id']).toList();
      res = [...res, user];
    } else {
      sel = [...state.selected, user];
      res = res.where((r) => r['id'] != user['id']).toList();
    }
    state = state.copyWith(selected: sel, results: res);
  }

  void addSelectedForSingle(Map<String,dynamic> user) {
    if (state.selected.isEmpty) {
      state = state.copyWith(selected: [user], results: state.results.where((r) => r['id'] != user['id']).toList());
    }
  }

  void setCreating(bool v) => state = state.copyWith(isCreating: v);

  void updateStatus(String userId, String status) {
    final m = Map<String,String>.from(state.connStatus)..[userId] = status;
    state = state.copyWith(connStatus: m);
  }

  @override 
  void dispose() { 
    _debounce?.cancel(); 
    super.dispose(); 
  }
}

final newConvProvider = StateNotifierProvider<NewConvNotifier, NewConvState>((ref) {
  return NewConvNotifier(Supabase.instance.client, ConnectionService());
});

class NewConversationPage extends ConsumerStatefulWidget {
  const NewConversationPage({super.key});
  @override 
  ConsumerState<NewConversationPage> createState() => _NewConversationPageState();
}

class _NewConversationPageState extends ConsumerState<NewConversationPage> {
  final _searchCtrl = TextEditingController();
  final _scroll = ScrollController();
  late ChatService _chatService;

  @override 
  void initState() {
    super.initState();
    _chatService = ChatService(Supabase.instance.client);
    _scroll.addListener(() { 
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300) {
        ref.read(newConvProvider.notifier).loadMore(); 
      }
    });
  }

  @override 
  void dispose() { 
    _searchCtrl.dispose(); 
    _scroll.dispose(); 
    super.dispose(); 
  }

  (String, Color) _statusDisplay(String? s) {
    switch(s) {
      case 'connected': return ('Connecté', _C.green);
      case 'pending': return ('En attente', Colors.orange);
      case 'rejected': return ('Refusé', _C.red);
      default: return ('', Colors.transparent);
    }
  }

  void _onUserTap(Map<String,dynamic> user) {
    final state = ref.read(newConvProvider);
    final curId = Supabase.instance.client.auth.currentUser?.id;
    if (user['id'] == curId) { 
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pas vous-même'))); 
      return; 
    }
    
    final status = state.connStatus[user['id']] ?? 'none';
    
    if (status == 'connected') {
      if (state.selected.isEmpty) { 
        ref.read(newConvProvider.notifier).addSelectedForSingle(user); 
        _startChat(); 
      } else {
        ref.read(newConvProvider.notifier).toggleSelect(user);
      }
    } else if (status == 'pending') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Demande en attente'), backgroundColor: Colors.orange));
    } else if (status == 'rejected') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Refusé'), backgroundColor: _C.red));
    } else {
      _showRequestDialog(user);
    }
  }

  void _showRequestDialog(Map<String,dynamic> user) {
    final msgCtrl = TextEditingController();
    showDialog(
      context: context, 
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white, 
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: _C.border)),
        title: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: _C.surface,
              backgroundImage: user['avatar_url'] != null ? NetworkImage(user['avatar_url']) : null,
              child: user['avatar_url'] == null ? const Icon(Icons.person, color: _C.textMuted) : null,
            ), 
            const SizedBox(width: 12), 
            Expanded(
              child: Text('Demander à ${user['display_name']}', style: const TextStyle(color: _C.textMain, fontSize: 16, fontWeight: FontWeight.bold))
            )
          ]
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Envoyez une demande de connexion pour discuter de manière sécurisée.', style: TextStyle(color: _C.textMuted, fontSize: 14)), 
            const SizedBox(height: 16), 
            TextField(
              controller: msgCtrl,
              style: const TextStyle(color: _C.textMain, fontSize: 14),
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Message optionnel...',
                hintStyle: const TextStyle(color: _C.textMuted, fontSize: 14),
                filled: true,
                fillColor: _C.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _C.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _C.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _C.primary))
              )
            )
          ]
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx), 
            child: const Text('Annuler', style: TextStyle(color: _C.textMuted, fontWeight: FontWeight.w600))
          ), 
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _C.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ), 
            onPressed: () async { 
              Navigator.pop(ctx); 
              await _sendRequest(user, msgCtrl.text.trim()); 
            }, 
            child: const Text('Envoyer la demande', style: TextStyle(fontWeight: FontWeight.bold))
          )
        ],
      )
    );
  }

  Future<void> _sendRequest(Map<String,dynamic> user, String msg) async {
    final cur = Supabase.instance.client.auth.currentUser?.id; 
    if (cur == null) return;
    final svc = ConnectionService();
    final ok = await svc.sendRequest(senderId: cur, receiverId: user['id'], message: msg.isNotEmpty ? msg : null);
    
    if (ok) { 
      ref.read(newConvProvider.notifier).updateStatus(user['id'], 'pending'); 
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Demande envoyée'), backgroundColor: _C.green)); 
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(svc.error ?? 'Demande existante'), backgroundColor: _C.red));
    }
  }

  Future<void> _startChat() async {
    final state = ref.read(newConvProvider);
    if (state.selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sélectionnez un contact')),
      );
      return;
    }

    final cur = Supabase.instance.client.auth.currentUser?.id;
    if (cur == null) return;

    final notConnected = state.selected.where((u) {
      final s = state.connStatus[u['id']] ?? 'none';
      return s != 'connected';
    }).toList();

    if (notConnected.isNotEmpty) {
      final names = notConnected.map((u) => u['display_name']).join(', ');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('En attente de connexion: $names'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    ref.read(newConvProvider.notifier).setCreating(true);
    try {
      // ── 1 contact = DM via RPC (RLS-safe) ──
      if (state.selected.length == 1) {
        final otherId = state.selected.first['id'] as String;
        final conv = await _chatService.createDirectConversation(otherId);
        if (mounted) {
          context.pushReplacement(AppRoutes.chatDetail(conv.id), extra: conv);
        }
        return;
      }

      // ── Plusieurs = groupe (nécessite RPC groupe, sinon erreur claire) ──
      throw Exception(
        'Création de groupe : utilisez une RPC create_group_conversation '
        '(insert multi-participants bloqué par RLS).',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: _C.red),
        );
      }
    } finally {
      ref.read(newConvProvider.notifier).setCreating(false);
    }
  }

  @override 
  Widget build(BuildContext context) {
    final state = ref.watch(newConvProvider);
    final notifier = ref.read(newConvProvider.notifier);

    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 2,
        shadowColor: Colors.black.withOpacity(0.1),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: _C.textMain, size: 24), 
          onPressed: () => Navigator.pop(context),
          splashRadius: 24,
        ), 
        title: const Text('Nouvelle discussion', style: TextStyle(color: _C.textMain, fontSize: 18, fontWeight: FontWeight.bold)), 
        actions: [
          if (state.selected.isNotEmpty) 
            state.isCreating 
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: _C.primary))
                ) 
              : Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Center(
                    child: InkWell(
                      onTap: _startChat,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(color: _C.primary, borderRadius: BorderRadius.circular(20)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.send_rounded, size: 14, color: Colors.white),
                            const SizedBox(width: 6),
                            Text('Démarrer (${state.selected.length})', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))
                          ]
                        )
                      )
                    ),
                  )
                )
        ]
      ),
      body: Column(
        children: [
          // Champ de recherche
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0), 
            child: Container(
              decoration: BoxDecoration(color: _C.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: _C.border)), 
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => notifier.search(v),
                style: const TextStyle(color: _C.textMain, fontSize: 15, fontWeight: FontWeight.w500),
                decoration: InputDecoration(
                  hintText: 'Rechercher @THIX ou nom...',
                  hintStyle: const TextStyle(color: _C.textMuted, fontSize: 15),
                  prefixIcon: const Icon(Icons.search_rounded, color: _C.textMuted, size: 20),
                  suffixIcon: _searchCtrl.text.isNotEmpty 
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, color: _C.textMuted, size: 18),
                        onPressed: () { _searchCtrl.clear(); notifier.search(''); }
                      ) 
                    : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14)
                )
              )
            )
          ),
          
          // Champ Nom de groupe (si plusieurs sélectionnés)
          if (state.selected.length > 1) 
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0), 
              child: Container(
                decoration: BoxDecoration(color: _C.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: _C.border)), 
                child: TextField(
                  onChanged: (v) => notifier.setGroupName(v),
                  style: const TextStyle(color: _C.textMain, fontSize: 15),
                  decoration: const InputDecoration(
                    hintText: 'Nom du groupe (optionnel)',
                    hintStyle: TextStyle(color: _C.textMuted, fontSize: 15),
                    prefixIcon: Icon(Icons.groups_rounded, color: _C.textMuted, size: 20),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 14)
                  )
                )
              )
            ),
            
          // Liste horizontale des sélectionnés
          if (state.selected.isNotEmpty) 
            Container(
              height: 60,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0), 
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: state.selected.length,
                itemBuilder: (ctx, i) { 
                  final u = state.selected[i]; 
                  
                  // Extraction de la certification pour le petit badge
                  CertificationTier? selTier;
                  CertificationStatus? selStatus;
                  bool selIsCertified = false;
                  bool selIsLegacyVerified = u['is_verified'] == true;

                  if (u.containsKey('certification_tier') && u['certification_tier'] != null) {
                    selTier = CertificationTierX.parse(u['certification_tier']);
                    selStatus = CertificationStatusX.parse(u['certification_status']);
                    selIsCertified = selStatus == CertificationStatus.approved || selStatus == CertificationStatus.generated;
                  }

                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Container(
                      padding: const EdgeInsets.only(left: 6, right: 10),
                      decoration: BoxDecoration(
                        color: _C.primaryLight, 
                        borderRadius: BorderRadius.circular(20), 
                        border: Border.all(color: _C.primary.withOpacity(0.2))
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundImage: u['avatar_url'] != null ? NetworkImage(u['avatar_url']) : null,
                            backgroundColor: _C.primary,
                            child: u['avatar_url'] == null ? const Icon(Icons.person, size: 14, color: Colors.white) : null,
                          ),
                          const SizedBox(width: 8),
                          Text(u['display_name'] ?? '', style: const TextStyle(color: _C.primary, fontSize: 13, fontWeight: FontWeight.bold)),
                          if (selIsCertified)
                            CertificationNameBadge(
                              tier: selTier,
                              status: selStatus,
                              showLabel: false,
                              iconSize: 12,
                              padding: const EdgeInsets.only(left: 4),
                            )
                          else if (selIsLegacyVerified)
                            const Padding(
                              padding: EdgeInsets.only(left: 4),
                              child: Icon(Icons.verified_rounded, color: Color(0xFFE3B23C), size: 12),
                            ),
                          const SizedBox(width: 6),
                          InkWell(
                            onTap: () => notifier.toggleSelect(u),
                            child: const Icon(Icons.close_rounded, size: 16, color: _C.primary)
                          )
                        ]
                      )
                    )
                  ); 
                }
              )
            ),
            
          // Résultats
          Expanded(
            child: state.isLoading && state.results.isEmpty
              ? const Center(child: CircularProgressIndicator(color: _C.primary, strokeWidth: 3)) 
              : state.results.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 80, height: 80, 
                          decoration: BoxDecoration(color: _C.surface, shape: BoxShape.circle, border: Border.all(color: _C.border)),
                          child: const Icon(Icons.people_outline_rounded, color: _C.textMuted, size: 36)
                        ),
                        const SizedBox(height: 16),
                        Text(_searchCtrl.text.isEmpty ? 'Recherchez un utilisateur' : 'Aucun résultat trouvé', style: const TextStyle(color: _C.textMain, fontSize: 16, fontWeight: FontWeight.bold)),
                        if (_searchCtrl.text.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text('Commencez à taper un nom ou un ID', style: TextStyle(color: _C.textMuted, fontSize: 14)),
                          )
                      ]
                    )
                  ) 
                : ListView.separated(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                    itemCount: state.results.length + (state.hasMore ? 1 : 0),
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) { 
                      if (i == state.results.length) {
                        return const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator(color: _C.primary, strokeWidth: 3))); 
                      }
                      
                      final user = state.results[i]; 
                      final id = user['id']; 
                      final isSel = state.selected.any((s) => s['id'] == id); 
                      final (label, color) = _statusDisplay(state.connStatus[id]); 
                      
                      // Extraction de la certification pour le résultat
                      CertificationTier? tier;
                      CertificationStatus? status;
                      bool isCertified = false;
                      bool isLegacyVerified = user['is_verified'] == true;

                      if (user.containsKey('certification_tier') && user['certification_tier'] != null) {
                        tier = CertificationTierX.parse(user['certification_tier']);
                        status = CertificationStatusX.parse(user['certification_status']);
                        isCertified = status == CertificationStatus.approved || status == CertificationStatus.generated;
                      }

                      return InkWell(
                        onTap: () => _onUserTap(user),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: isSel ? _C.primary : _C.border, width: isSel ? 1.5 : 1),
                            boxShadow: isSel ? [BoxShadow(color: _C.primary.withOpacity(0.1), blurRadius: 8)] : []
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: _C.surface,
                                backgroundImage: user['avatar_url'] != null ? NetworkImage(user['avatar_url']) : null,
                                child: user['avatar_url'] == null ? const Icon(Icons.person_rounded, color: _C.textMuted, size: 24) : null
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(child: Text(user['display_name'] ?? 'Utilisateur', style: const TextStyle(color: _C.textMain, fontWeight: FontWeight.bold, fontSize: 16), overflow: TextOverflow.ellipsis)),
                                        if (isCertified)
                                          CertificationNameBadge(
                                            tier: tier,
                                            status: status,
                                            showLabel: false,
                                            iconSize: 15,
                                            padding: const EdgeInsets.only(left: 4),
                                          )
                                        else if (isLegacyVerified)
                                          const Padding(
                                            padding: EdgeInsets.only(left: 4),
                                            child: Icon(Icons.verified_rounded, color: Color(0xFFE3B23C), size: 15),
                                          ),
                                        const SizedBox(width: 8),
                                        if (label.isNotEmpty) 
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withOpacity(0.2))),
                                            child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold))
                                          )
                                      ]
                                    ),
                                    const SizedBox(height: 2),
                                    if ((user['profession'] ?? '').toString().isNotEmpty) 
                                      Text(user['profession'], style: const TextStyle(color: _C.textMuted, fontSize: 13)),
                                    if (user['thix_chat'] != null) 
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Text(user['thix_chat'], style: const TextStyle(color: _C.primary, fontSize: 12, fontWeight: FontWeight.bold)),
                                      )
                                  ]
                                )
                              ),
                              if (label == 'Connecté') 
                                isSel 
                                  ? const Icon(Icons.check_circle_rounded, color: _C.primary, size: 28) 
                                  : Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: _C.border)),
                                      child: const Icon(Icons.add_rounded, color: _C.textMain, size: 20)
                                    ) 
                              else if (label == 'En attente') 
                                const Icon(Icons.hourglass_top_rounded, color: Colors.orange, size: 24) 
                              else if (label == 'Refusé') 
                                const Icon(Icons.block_rounded, color: _C.red, size: 24) 
                              else 
                                IconButton(
                                  icon: const Icon(Icons.person_add_alt_1_rounded, color: _C.primary, size: 24),
                                  onPressed: () => _showRequestDialog(user),
                                  splashRadius: 24,
                                )
                            ]
                          )
                        ),
                      ); 
                    }
                  )
          ),
        ]
      ),
    );
  }
}
