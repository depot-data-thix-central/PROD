// ============================================================================
// THIX WEDDING & EVENTS — MY WEDDINGS (avec Recherche & Demandes d'accès)
// ============================================================================
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/presentation/thix_weeding/pages/staff/models/thix_weeding_models.dart';
import 'package:thix_id/presentation/thix_weeding/pages/staff/providers/thix_weeding_providers.dart';

const TextStyle _monoStyle = TextStyle(
  fontFamily: 'monospace',
  fontFeatures: [FontFeature.tabularFigures()],
  letterSpacing: 0.5,
);

TextStyle _mono({double? fontSize, FontWeight? fontWeight, Color? color, double? letterSpacing}) {
  return _monoStyle.copyWith(fontSize: fontSize, fontWeight: fontWeight, color: color, letterSpacing: letterSpacing);
}

class _R {
  static const Color blue = Color(0xFF0B3B8F);
  static const Color purple = Color(0xFF6B46C1);
  static const Color gold = Color(0xFFD4AF37);
  static const Color goldDark = Color(0xFFB8860B);
  static const Color rose = Color(0xFFE31C4E);
  static const Color green = Color(0xFF059669);
  static const Color greenSoft = Color(0xFF10B981);
  static const Color amber = Color(0xFFD97706);
  static const Color surface = Color(0xFFF8FAFC);
  static const Color cream = Color(0xFFFFFBF5);
  static const Color text = Color(0xFF111827);
  static const Color text2 = Color(0xFF6B7280);
  static const Color border = Color(0xFFE5E7EB);

  static const LinearGradient roseG = LinearGradient(
    colors: [rose, Color(0xFFFF6B9D)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient greenG = LinearGradient(
    colors: [green, greenSoft],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

// ============================================================================
// PAGE PRINCIPALE
// ============================================================================
class MyWeddingsPage extends ConsumerStatefulWidget {
  const MyWeddingsPage({super.key});

  @override
  ConsumerState<MyWeddingsPage> createState() => _MyWeddingsPageState();
}

class _MyWeddingsPageState extends ConsumerState<MyWeddingsPage> {
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  bool _hasSearched = false;

  Future<void> _refresh(String userId) async {
    ref.invalidate(myWeddingsProvider(userId));
    await ref.read(myWeddingsProvider(userId).future);
  }

  // ── RECHERCHE PAR ID ──
  Future<void> _searchWedding() async {
    final query = _searchCtrl.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isSearching = true;
      _hasSearched = true;
    });

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final res = await Supabase.instance.client
          .from('thix_weeding_weddings')
          .select()
          .eq('id', query)
          .limit(1);

      setState(() {
        _searchResults = List<Map<String, dynamic>>.from(res);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: _R.rose),
        );
      }
    } finally {
      setState(() => _isSearching = false);
    }
  }

  // ── DEMANDER L'ACCÈS ──
  Future<void> _requestAccess(String weddingId) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      await Supabase.instance.client.from('thix_weeding_staff_requests').upsert(
        {
          'wedding_id': weddingId,
          'user_id': user.id,
          'status': 'pending',
        },
        onConflict: 'wedding_id, user_id',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Demande envoyée au propriétaire !'),
            backgroundColor: _R.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: _R.rose),
        );
      }
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      return const Center(child: Text('Veuillez vous connecter.'));
    }

    final weddingsAsync = ref.watch(myWeddingsProvider(user.id));

    return Scaffold(
      backgroundColor: _R.cream,
      body: weddingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: _R.rose)),
        error: (e, _) => Center(child: Text('Erreur: $e')),
        data: (weddings) {
          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildAppBar(weddings.length),
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate(
                    [
                      // 1. BARRE DE RECHERCHE (par ID)
                      _buildSearchBar(),
                      const SizedBox(height: 20),

                      // 2. RÉSULTATS DE RECHERCHE
                      if (_hasSearched) _buildSearchResults(),

                      // 3. DEMANDES D'ACCÈS
                      _IncomingRequestsWidget(onActionDone: () => _refresh(user.id)),
                      const SizedBox(height: 10),

                      // 4. LISTE DES MARIAGES
                      Text(
                        'Mes événements',
                        style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: _R.text),
                      ),
                      const SizedBox(height: 12),
                      if (weddings.isEmpty)
                        const _EmptyState()
                      else
                        RefreshIndicator(
                          color: _R.rose,
                          onRefresh: () => _refresh(user.id),
                          child: Column(
                            children: weddings
                                .map(
                                  (w) => Padding(
                                    padding: const EdgeInsets.only(bottom: 14),
                                    child: _WeddingCard(wedding: w),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── WIDGETS ──

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: TextField(
        controller: _searchCtrl,
        onSubmitted: (_) => _searchWedding(),
        decoration: InputDecoration(
          hintText: 'Rechercher par ID (uuid)',
          hintStyle: GoogleFonts.inter(fontSize: 13, color: _R.text2),
          prefixIcon: const Icon(Icons.search, color: _R.blue),
          suffixIcon: IconButton(
            icon: _isSearching
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: _R.blue))
                : const Icon(Icons.arrow_forward, color: _R.blue),
            onPressed: _searchWedding,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_isSearching) {
      return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
    }
    if (_searchResults.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Text(
          'Aucun mariage trouvé pour cette recherche.',
          style: GoogleFonts.inter(color: _R.text2, fontStyle: FontStyle.italic),
        ),
      );
    }

    final w = _searchResults.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Résultats de recherche',
          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: _R.text),
        ),
        const SizedBox(height: 10),
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _R.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      w['couple_names'] ?? 'Sans nom',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                    Text('ID: ${w['id']}', style: _mono(fontSize: 11, color: _R.blue)),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _requestAccess(w['id']),
                icon: const Icon(Icons.person_add_alt_1, size: 16),
                label: const Text('Demander accès'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _R.blue.withOpacity(0.1),
                  foregroundColor: _R.blue,
                  elevation: 0,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 30),
      ],
    );
  }

  Widget _buildAppBar(int count) {
    return SliverAppBar(
      expandedHeight: 140,
      pinned: true,
      backgroundColor: Colors.white,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)],
          ),
          child: const Icon(Icons.arrow_back_ios_new, size: 14, color: _R.text),
        ),
        onPressed: () => context.pop(),
      ),
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: _R.roseG,
          borderRadius: BorderRadius.only(bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24)),
        ),
        child: FlexibleSpaceBar(
          background: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.start, // CORRIGÉ
                children: [
                  Text(
                    'Gérez vos événements',
                    style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                  Text(
                    '${count} mariage${count > 1 ? 's' : ''} créé${count > 1 ? 's' : ''}', // CORRIGÉ
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withOpacity(0.9)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// DEMANDES D'ACCÈS (inchangé)
// ============================================================================
class _IncomingRequestsWidget extends StatefulWidget {
  final VoidCallback onActionDone;
  const _IncomingRequestsWidget({required this.onActionDone});

  @override
  State<_IncomingRequestsWidget> createState() => _IncomingRequestsWidgetState();
}

class _IncomingRequestsWidget extends ConsumerStatefulWidget {
  List<Map<String, dynamic>> _requests = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchRequests();
  }

  Future<void> _fetchRequests() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final res = await Supabase.instance.client
          .from('thix_weeding_staff_requests')
          .select('*, thix_weeding_weddings!inner(couple_names, owner_id)')
          .eq('status', 'pending')
          .eq('thix_weeding_weddings.owner_id', user.id);

      if (mounted) {
        setState(() {
          _requests = List<Map<String, dynamic>>.from(res);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleRequest(String requestId, String weddingId, String userId, bool accept) async {
    try {
      await Supabase.instance.client.from('thix_weeding_staff_requests').update({
        'status': accept ? 'approved' : 'rejected',
      }).eq('id', requestId);

      if (accept) {
        await Supabase.instance.client.from('thix_weeding_staff_members').upsert(
          {
            'wedding_id': weddingId,
            'user_id': userId,
          },
          onConflict: 'wedding_id, user_id',
        );
      }

      _fetchRequests();
      widget.onActionDone();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: _R.rose),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();
    if (_requests.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.notifications_active, color: _R.amber, size: 20),
            const SizedBox(width: 8),
            Text(
              'Demandes d\'accès (${_requests.length})',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900, color: _R.text),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ..._requests.map((r) {
          final w = r['thix_weeding_weddings'] as Map<String, dynamic>;
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _R.amber.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _R.amber.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const CircleAvatar(backgroundColor: Colors.white, child: Icon(Icons.person, color: _R.amber)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Demande pour ${w['couple_names']}',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                      Text(
                        'Souhaite rejoindre l\'équipe staff',
                        style: GoogleFonts.inter(fontSize: 11, color: _R.text2),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.check_circle, color: _R.green),
                  onPressed: () => _handleRequest(r['id'], r['wedding_id'], r['user_id'], true),
                ),
                IconButton(
                  icon: const Icon(Icons.cancel, color: _R.rose),
                  onPressed: () => _handleRequest(r['id'], r['wedding_id'], r['user_id'], false),
                ),
              ],
            ),
          );
        }),
        const Divider(height: 30),
      ],
    );
  }
}

// ============================================================================
// CARTE MARIAGE (inchangée)
// ============================================================================
class _WeddingCard extends ConsumerWidget {
  final WeddingModel wedding;
  const _WeddingCard({required this.wedding});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: () => context.push('/thix-weeding/staff/${wedding.id}'),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: wedding.invitationPublished ? _R.green.withOpacity(0.3) : _R.border,
              width: wedding.invitationPublished ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4)),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  gradient: _R.roseG,
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                ),
                child: const Center(child: Icon(Icons.favorite, color: Colors.white, size: 28)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      wedding.coupleNames.isEmpty ? 'Mariage sans nom' : wedding.coupleNames,
                      style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: _R.text),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      wedding.venue ?? 'Lieu à définir',
                      style: GoogleFonts.inter(fontSize: 11, color: _R.text2),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _R.blue.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        wedding.uniqueCode,
                        style: _mono(fontSize: 9, fontWeight: FontWeight.w700, color: _R.blue),
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 20, color: _R.text2),
                onSelected: (v) {
                  if (v == 'delete') _delete(context, ref);
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Supprimer', style: TextStyle(color: _R.rose)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer ce mariage ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer', style: TextStyle(color: _R.rose)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(weddingServiceProvider).delete(wedding.id);
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) ref.invalidate(myWeddingsProvider(userId));
    }
  }
}

class _EmptyState extends StatelessWidget { // CORRIGÉ (Statelessheet -> StatelessWidget)
  const _EmptyState();
  
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          const Icon(Icons.favorite_border, size: 48, color: _R.rose),
          const SizedBox(height: 16),
          Text(
            'Aucun mariage',
            style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () => context.push('/thix-weeding/create'),
            style: FilledButton.styleFrom(backgroundColor: _R.rose),
            child: const Text('Créer un mariage'),
          ),
        ],
      ),
    );
  }
}
