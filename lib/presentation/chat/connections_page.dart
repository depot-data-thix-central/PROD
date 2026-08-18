// lib/presentation/chat/connections_page.dart
import 'dart:ui'; // ✅ Corrigé : i minuscule
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

import '../../services/chat/connection_service.dart';

// ✅ Imports nécessaires pour lancer les appels et les chats
import 'call/providers/call_provider.dart';
import 'call/call_page.dart';
import '../../../models/chat/call_status.dart'; // Pour CallType
import 'providers/chat_providers.dart'; // Si vous avez besoin du ChatService

// ✅ Imports pour la certification
import 'package:thix_id/models/certification_tier.dart';
import 'package:thix_id/presentation/certification/widgets/certification_name_badge.dart';

// Palette "Grandeur Entreprise" (Thème Clair & Lumineux)
class _C {
  static const bg = Color(0xFFF8FAFC); 
  static const surface = Colors.white;
  static const border = Color(0xFFE2E8F0);
  static const primary = Color(0xFF1D4ED8); // Bleu "Trust"
  static const primaryLight = Color(0xFFEFF6FF);
  static const textMain = Color(0xFF0F172A);
  static const textMuted = Color(0xFF64748B);
  static const red = Color(0xFFEF4444);
  static const redLight = Color(0xFFFEF2F2);
  static const green = Color(0xFF22C55E);
  static const orange = Color(0xFFF59E0B);
  static const warningBg = Color(0xFFFFFBEB);
}

class ConnectionsState {
  final List<ConnectionRequest> received;
  final List<ConnectionRequest> sent;
  final List<dynamic> connections;
  final bool loading;
  final bool loadingMore;
  final bool hasMoreConnections;
  final String? error;

  const ConnectionsState({
    this.received = const [], 
    this.sent = const [], 
    this.connections = const [], 
    this.loading = true, 
    this.loadingMore = false, 
    this.hasMoreConnections = true, 
    this.error
  });

  ConnectionsState copyWith({
    List<ConnectionRequest>? received, 
    List<ConnectionRequest>? sent, 
    List<dynamic>? connections, 
    bool? loading, 
    bool? loadingMore, 
    bool? hasMoreConnections, 
    String? error
  }) {
    return ConnectionsState(
      received: received ?? this.received, 
      sent: sent ?? this.sent, 
      connections: connections ?? this.connections, 
      loading: loading ?? this.loading, 
      loadingMore: loadingMore ?? this.loadingMore, 
      hasMoreConnections: hasMoreConnections ?? this.hasMoreConnections, 
      error: error
    );
  }
}

class ConnectionsNotifier extends StateNotifier<ConnectionsState> {
  final ConnectionService _svc;
  static const _limit = 20;
  
  ConnectionsNotifier(this._svc) : super(const ConnectionsState()) { 
    loadInitial(); 
  }

  Future<void> loadInitial() async {
    state = state.copyWith(loading: true);
    final uid = Supabase.instance.client.auth.currentUser?.id;
    
    if (uid == null) { 
      state = state.copyWith(loading: false); 
      return; 
    }
    
    try {
      await _svc.loadData(uid, limit: _limit, offset: 0);
      state = ConnectionsState(
        received: _svc.receivedRequests,
        sent: _svc.sentRequests,
        connections: _svc.connections,
        loading: false,
        hasMoreConnections: _svc.connections.length == _limit,
      );
    } catch (e) { 
      state = state.copyWith(loading: false, error: e.toString()); 
    }
  }

  Future<void> loadMoreConnections() async {
    if (state.loadingMore || !state.hasMoreConnections) return;
    
    state = state.copyWith(loadingMore: true);
    final uid = Supabase.instance.client.auth.currentUser?.id;
    
    if (uid == null) { 
      state = state.copyWith(loadingMore: false); 
      return; 
    }
    
    try {
      final more = await _svc.loadMoreConnections(uid, offset: state.connections.length, limit: _limit);
      state = state.copyWith(
        connections: [...state.connections, ...more], 
        hasMoreConnections: more.length == _limit, 
        loadingMore: false
      );
    } catch (_) { 
      state = state.copyWith(loadingMore: false); 
    }
  }

  Future<bool> accept(String id) async {
    final uid = Supabase.instance.client.auth.currentUser?.id; 
    if (uid == null) return false;
    final ok = await _svc.acceptRequest(id, uid); 
    if (ok) await loadInitial(); 
    return ok;
  }
  
  Future<bool> reject(String id) async {
    final uid = Supabase.instance.client.auth.currentUser?.id; 
    if (uid == null) return false;
    final ok = await _svc.rejectRequest(id, uid); 
    if (ok) await loadInitial(); 
    return ok;
  }
  
  Future<bool> cancel(String id) async {
    final uid = Supabase.instance.client.auth.currentUser?.id; 
    if (uid == null) return false;
    final ok = await _svc.cancelRequest(id, uid); 
    if (ok) await loadInitial(); 
    return ok;
  }

  // ✅ Retirer une connexion avec mise à jour UI
  Future<bool> removeConnection(String otherUserId) async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return false;
    try {
      final ok = await _svc.removeConnection(uid, otherUserId);
      if (ok) {
        state = state.copyWith(
          connections: state.connections.where((c) => c['user_id'] != otherUserId).toList()
        );
      }
      return ok;
    } catch (e) {
      return false;
    }
  }

  // ✅ Bloquer un utilisateur avec mise à jour UI
  Future<bool> blockUser(String otherUserId) async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return false;
    try {
      final ok = await _svc.blockUser(uid, otherUserId);
      if (ok) {
        state = state.copyWith(
          connections: state.connections.where((c) => c['user_id'] != otherUserId).toList()
        );
      }
      return ok;
    } catch (e) {
      return false;
    }
  }
}

final connectionsProvider = StateNotifierProvider<ConnectionsNotifier, ConnectionsState>((ref) {
  return ConnectionsNotifier(ConnectionService());
});

class ConnectionsPage extends ConsumerStatefulWidget {
  const ConnectionsPage({super.key});
  @override 
  ConsumerState<ConnectionsPage> createState() => _ConnectionsPageState();
}

class _ConnectionsPageState extends ConsumerState<ConnectionsPage> {
  final _scroll = ScrollController();
  
  @override 
  void initState() { 
    super.initState(); 
    _scroll.addListener(() { 
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300) {
        ref.read(connectionsProvider.notifier).loadMoreConnections(); 
      }
    }); 
  }
  
  @override 
  void dispose() { 
    _scroll.dispose(); 
    super.dispose(); 
  }

  // ─── ACTIONS DE COMMUNICATION (LANCER APPELS ET CHAT) ───

  Future<void> _startChat(Map<String, dynamic> connection) async {
    try {
      // Afficher un indicateur de chargement si la création prend du temps
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ouverture de la discussion...'), duration: Duration(seconds: 1)));
      
      final currentUserId = Supabase.instance.client.auth.currentUser!.id;
      final otherUserId = connection['user_id'];
      
      // Ici, vous pouvez chercher ou créer la conversation via votre backend.
      // Si vous avez un routeur GoRouter paramétré pour chercher automatiquement via l'ID utilisateur :
      // context.pushNamed('chatScreenByUserId', pathParameters: {'userId': otherUserId});
      
      // Exemple avec recherche directe Supabase (si applicable dans votre architecture) :
      final res = await Supabase.instance.client
          .from('conversations')
          .select('id')
          .contains('participant_ids', [currentUserId, otherUserId])
          .eq('is_group', false)
          .maybeSingle();

      if (res != null && mounted) {
        // Conversation trouvée, on ouvre le ChatScreen !
        context.push('/chat/${res['id']}'); // Adaptez avec votre route exacte
      } else {
        // Logique de création à insérer ici ou via votre ChatService
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Impossible de démarrer le chat directement.'), backgroundColor: _C.orange));
      }
    } catch (e) {
      debugPrint('Erreur lancement chat: $e');
    }
  }

  void _startAudioCall(Map<String, dynamic> connection) {
    final myId = Supabase.instance.client.auth.currentUser!.id;
    ref.read(callProvider.notifier).start(
      myUserId: myId,
      calleeId: connection['user_id'], // L'ID cible de l'utilisateur
      calleeName: connection['display_name'] ?? 'Contact',
      calleeAvatar: connection['avatar_url'],
      type: CallType.audio,
    );
    Navigator.push(context, MaterialPageRoute(builder: (_) => const CallPage()));
  }

  void _startVideoCall(Map<String, dynamic> connection) {
    final myId = Supabase.instance.client.auth.currentUser!.id;
    ref.read(callProvider.notifier).start(
      myUserId: myId,
      calleeId: connection['user_id'], // L'ID cible de l'utilisateur
      calleeName: connection['display_name'] ?? 'Contact',
      calleeAvatar: connection['avatar_url'],
      type: CallType.video,
    );
    Navigator.push(context, MaterialPageRoute(builder: (_) => const CallPage()));
  }

  // ─── BOÎTES DE DIALOGUE (SÉCURITÉ ENTREPRISE) ───

  Future<void> _confirmCancel(String id) async {
    final ok = await showDialog<bool>(
      context: context, 
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white, 
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: _C.border)),
        title: const Text('Annuler la demande ?', style: TextStyle(color: _C.textMain, fontWeight: FontWeight.bold, fontSize: 18)),
        content: const Text('Cette action retirera votre demande de connexion en attente.', style: TextStyle(color: _C.textMuted, fontSize: 14)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Non', style: TextStyle(color: _C.textMuted, fontWeight: FontWeight.w600))), 
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _C.red, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), 
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text('Oui, annuler', style: TextStyle(fontWeight: FontWeight.bold))
          )
        ],
      )
    );
    
    if (ok == true) { 
      final svc = ref.read(connectionsProvider.notifier); 
      final res = await svc.cancel(id); 
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res ? 'Demande annulée avec succès' : 'Erreur lors de l\'annulation'), backgroundColor: res ? _C.textMuted : _C.red)); 
      }
    }
  }

  Future<void> _confirmRemove(Map<String, dynamic> connection) async {
    final ok = await showDialog<bool>(
      context: context, 
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white, 
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Retirer du réseau', style: TextStyle(color: _C.textMain, fontWeight: FontWeight.bold, fontSize: 18)),
        content: Text('Voulez-vous vraiment retirer ${connection['display_name']} de vos connexions ?', style: const TextStyle(color: _C.textMuted, fontSize: 14)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler', style: TextStyle(color: _C.textMuted, fontWeight: FontWeight.w600))), 
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _C.orange, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), 
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text('Retirer', style: TextStyle(fontWeight: FontWeight.bold))
          )
        ],
      )
    );
    
    if (ok == true) { 
      final res = await ref.read(connectionsProvider.notifier).removeConnection(connection['user_id']); 
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res ? 'Connexion retirée' : 'Erreur'), backgroundColor: res ? _C.textMuted : _C.red)); 
    }
  }

  Future<void> _confirmBlock(Map<String, dynamic> connection) async {
    final ok = await showDialog<bool>(
      context: context, 
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white, 
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [Icon(Icons.block, color: _C.red), SizedBox(width: 8), Text('Bloquer l\'utilisateur', style: TextStyle(color: _C.red, fontWeight: FontWeight.bold, fontSize: 18))]),
        content: const Text('Cette personne ne pourra plus vous contacter ni voir votre profil. Cette action est définitive.', style: TextStyle(color: _C.textMuted, fontSize: 14)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler', style: TextStyle(color: _C.textMuted, fontWeight: FontWeight.w600))), 
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _C.red, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), 
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text('Bloquer', style: TextStyle(fontWeight: FontWeight.bold))
          )
        ],
      )
    );
    
    if (ok == true) { 
      final res = await ref.read(connectionsProvider.notifier).blockUser(connection['user_id']); 
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res ? 'Utilisateur bloqué' : 'Erreur'), backgroundColor: _C.red)); 
    }
  }

  // ─── BOTTOM SHEET (MENU ACTIONS) ───

  void _showConnectionActions(Map<String, dynamic> connection) {
    HapticFeedback.selectionClick();
    final name = connection['display_name'] ?? 'Utilisateur inconnu';
    final role = connection['role'] ?? 'Membre du réseau';
    final avatarUrl = connection['avatar_url'];

    // ✅ Extraction de la certification pour le menu
    CertificationTier? tier = CertificationTierX.parse(connection['certification_tier']);
    CertificationStatus? status = CertificationStatusX.parse(connection['certification_status']);
    bool isCertified = status == CertificationStatus.approved || status == CertificationStatus.generated;
    bool isLegacyVerified = connection['is_verified'] == true;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.only(bottom: 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: _C.border, borderRadius: BorderRadius.circular(4))),
            
            // Header du Profil
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: _C.primaryLight,
                    backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                    child: avatarUrl == null ? const Icon(Icons.person, color: _C.primary, size: 32) : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _C.textMain), maxLines: 1, overflow: TextOverflow.ellipsis),
                            ),
                            if (isCertified)
                              CertificationNameBadge(
                                tier: tier,
                                status: status,
                                showLabel: false,
                                iconSize: 18,
                                padding: const EdgeInsets.only(left: 6),
                              )
                            else if (isLegacyVerified)
                              const Padding(
                                padding: EdgeInsets.only(left: 6),
                                child: Icon(Icons.verified_rounded, color: Color(0xFFE3B23C), size: 18),
                              ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(role, style: const TextStyle(fontSize: 14, color: _C.textMuted, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Barre d'actions rapides (Chat / Call)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Expanded(
                    child: _QuickActionButton(
                      icon: Icons.chat_bubble_rounded, label: 'Message', color: _C.primary,
                      onTap: () { Navigator.pop(ctx); _startChat(connection); },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _QuickActionButton(
                      icon: Icons.call_rounded, label: 'Audio', color: _C.green,
                      onTap: () { Navigator.pop(ctx); _startAudioCall(connection); },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _QuickActionButton(
                      icon: Icons.videocam_rounded, label: 'Vidéo', color: _C.orange,
                      onTap: () { Navigator.pop(ctx); _startVideoCall(connection); },
                    ),
                  ),
                ],
              ),
            ),

            const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(height: 1, color: _C.border)),

            // Liste des actions de gestion de réseau sécurisées
            _ActionListTile(
              icon: Icons.person_outline_rounded, title: 'Voir le profil complet',
              onTap: () { Navigator.pop(ctx); /* context.push('/profile/${connection['user_id']}'); */ },
            ),
            _ActionListTile(
              icon: Icons.person_remove_rounded, title: 'Retirer du réseau', color: _C.orange,
              onTap: () { Navigator.pop(ctx); _confirmRemove(connection); },
            ),
            _ActionListTile(
              icon: Icons.block_rounded, title: 'Bloquer cet utilisateur', color: _C.red,
              onTap: () { Navigator.pop(ctx); _confirmBlock(connection); },
            ),
          ],
        ),
      ),
    );
  }

  // ─── CONSTRUCTION DE L'INTERFACE ───

  @override 
  Widget build(BuildContext context) {
    final state = ref.watch(connectionsProvider);
    final notifier = ref.read(connectionsProvider.notifier);

    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 2,
        shadowColor: Colors.black.withOpacity(0.05),
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded, color: _C.textMain, size: 24), onPressed: () => Navigator.pop(context)), 
        title: const Text('Réseau & Connexions', style: TextStyle(color: _C.textMain, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.5)), 
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded, color: _C.textMain, size: 24), onPressed: () => notifier.loadInitial()),
          const SizedBox(width: 8),
        ]
      ),
      body: state.loading 
        ? const Center(child: CircularProgressIndicator(color: _C.primary, strokeWidth: 3)) 
        : RefreshIndicator(
            color: _C.primary, 
            backgroundColor: Colors.white,
            onRefresh: () async => notifier.loadInitial(),
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              children: [
                // SECTION: DEMANDES REÇUES
                if (state.received.isNotEmpty) ...[
                  _sectionTitle('Demandes reçues (${state.received.length})'),
                  ...state.received.map((r) => _buildReceivedRequestCard(r, notifier)),
                  const SizedBox(height: 16),
                ],
                
                // SECTION: DEMANDES ENVOYÉES
                if (state.sent.isNotEmpty) ...[
                  _sectionTitle('Demandes envoyées (${state.sent.length})'),
                  ...state.sent.map((r) => _buildSentRequestCard(r)),
                  const SizedBox(height: 16),
                ],
                
                // SECTION: CONNEXIONS ACTIVES
                _sectionTitle('Vos connexions (${state.connections.length})'),
                if (state.connections.isEmpty) 
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20), 
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: _C.border)), 
                    child: Column(
                      children: [
                        Container(padding: const EdgeInsets.all(16), decoration: const BoxDecoration(color: _C.bg, shape: BoxShape.circle), child: const Icon(Icons.people_outline_rounded, size: 40, color: _C.textMuted)),
                        const SizedBox(height: 16),
                        const Text('Aucune connexion pour le moment', style: TextStyle(color: _C.textMain, fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        const Text('Recherchez vos collègues et partenaires pour démarrer des discussions.', textAlign: TextAlign.center, style: TextStyle(color: _C.textMuted, fontSize: 14)),
                      ],
                    )
                  ),
                
                // Liste des connexions (SaaS Style)
                if (state.connections.isNotEmpty)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _C.border),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]
                    ),
                    child: Column(
                      children: state.connections.asMap().entries.map((entry) {
                        final i = entry.key;
                        final c = entry.value;
                        final isLast = i == state.connections.length - 1;
                        
                        return Column(
                          children: [
                            _buildConnectionItem(c),
                            if (!isLast) const Divider(height: 1, color: _C.border, indent: 76),
                          ],
                        );
                      }).toList(),
                    ),
                  ),

                if (state.loadingMore) 
                  const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator(color: _C.primary, strokeWidth: 3))),
                
                const SizedBox(height: 80),
              ],
            ),
          ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12, left: 4), 
      child: Text(title, style: const TextStyle(color: _C.textMain, fontWeight: FontWeight.w800, fontSize: 16))
    );
  }

  Widget _buildReceivedRequestCard(ConnectionRequest r, ConnectionsNotifier notifier) {
    final sender = r.sender ?? {};
    final name = sender['display_name'] ?? 'Utilisateur inconnu';
    final sub = r.message ?? 'Souhaite se connecter avec vous';
    final avatarUrl = sender['avatar_url'];

    // ✅ Extraction de la certification pour la demande reçue
    CertificationTier? tier = CertificationTierX.parse(sender['certification_tier']);
    CertificationStatus? status = CertificationStatusX.parse(sender['certification_status']);
    bool isCertified = status == CertificationStatus.approved || status == CertificationStatus.generated;
    bool isLegacyVerified = sender['is_verified'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.border),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: _C.primaryLight,
                  borderRadius: BorderRadius.circular(14),
                  image: avatarUrl != null ? DecorationImage(image: NetworkImage(avatarUrl), fit: BoxFit.cover) : null,
                ),
                child: avatarUrl == null ? Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(color: _C.primary, fontWeight: FontWeight.bold, fontSize: 18))) : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(name, style: const TextStyle(color: _C.textMain, fontWeight: FontWeight.bold, fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
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
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(sub, style: const TextStyle(color: _C.textMuted, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () async { 
                    final ok = await notifier.reject(r.id); 
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'Demande ignorée' : 'Erreur'), backgroundColor: _C.textMuted)); 
                  },
                  style: OutlinedButton.styleFrom(foregroundColor: _C.textMuted, side: const BorderSide(color: _C.border), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(vertical: 12)),
                  child: const Text('Ignorer', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async { 
                    final ok = await notifier.accept(r.id); 
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'Connexion acceptée' : 'Erreur'), backgroundColor: _C.green)); 
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: _C.primary, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(vertical: 12)),
                  child: const Text('Accepter', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSentRequestCard(ConnectionRequest r) {
    final receiver = r.receiver ?? {};
    final name = receiver['display_name'] ?? 'Utilisateur inconnu';
    final avatarUrl = receiver['avatar_url'];

    // ✅ Extraction de la certification pour la demande envoyée
    CertificationTier? tier = CertificationTierX.parse(receiver['certification_tier']);
    CertificationStatus? status = CertificationStatusX.parse(receiver['certification_status']);
    bool isCertified = status == CertificationStatus.approved || status == CertificationStatus.generated;
    bool isLegacyVerified = receiver['is_verified'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: _C.border)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(color: _C.bg, borderRadius: BorderRadius.circular(12), image: avatarUrl != null ? DecorationImage(image: NetworkImage(avatarUrl), fit: BoxFit.cover) : null),
          child: avatarUrl == null ? Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(color: _C.textMuted, fontWeight: FontWeight.bold, fontSize: 16))) : null,
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(name, style: const TextStyle(color: _C.textMain, fontWeight: FontWeight.bold, fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
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
          ],
        ),
        subtitle: Row(
          children: const [
            Icon(Icons.access_time_rounded, size: 14, color: _C.orange),
            SizedBox(width: 4),
            Text('En attente...', style: TextStyle(color: _C.orange, fontSize: 13, fontWeight: FontWeight.w500)),
          ],
        ),
        trailing: TextButton(
          onPressed: () => _confirmCancel(r.id), // ✅ Ajout du Cancel
          style: TextButton.styleFrom(foregroundColor: _C.textMuted),
          child: const Text('Annuler', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _buildConnectionItem(Map<String, dynamic> c) {
    final name = c['display_name'] ?? 'Utilisateur inconnu';
    final role = c['role'] ?? 'Réseau'; 
    final avatarUrl = c['avatar_url'];

    // ✅ Extraction de la certification pour l'item de connexion
    CertificationTier? tier = CertificationTierX.parse(c['certification_tier']);
    CertificationStatus? status = CertificationStatusX.parse(c['certification_status']);
    bool isCertified = status == CertificationStatus.approved || status == CertificationStatus.generated;
    bool isLegacyVerified = c['is_verified'] == true;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: _C.primaryLight,
          borderRadius: BorderRadius.circular(12),
          image: avatarUrl != null ? DecorationImage(image: NetworkImage(avatarUrl), fit: BoxFit.cover) : null,
        ),
        child: avatarUrl == null 
          ? Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(color: _C.primary, fontWeight: FontWeight.bold, fontSize: 16)))
          : null,
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(name, style: const TextStyle(color: _C.textMain, fontWeight: FontWeight.bold, fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
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
        ],
      ),
      subtitle: Text(role, style: const TextStyle(color: _C.textMuted, fontSize: 13)),
      trailing: IconButton(
        icon: const Icon(Icons.more_horiz_rounded, color: _C.textMuted),
        onPressed: () => _showConnectionActions(c),
      ),
      onTap: () => _showConnectionActions(c), // Ouvre le menu complet
    );
  }
}

// ─── COMPOSANTS UI ANNEXES POUR LE BOTTOM SHEET ───

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionButton({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class _ActionListTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color? color;
  final VoidCallback onTap;

  const _ActionListTile({required this.icon, required this.title, this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = color ?? _C.textMain;
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: c.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: c, size: 20),
      ),
      title: Text(title, style: TextStyle(color: c, fontSize: 15, fontWeight: FontWeight.w600)),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
    );
  }
}
