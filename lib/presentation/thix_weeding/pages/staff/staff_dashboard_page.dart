// lib/presentation/thix_weeding/pages/staff/staff_dashboard_page.dart
// ============================================================================
// THIX WEDDING & EVENTS — STAFF DASHBOARD (PRODUCTION v5)
// ✅ COMPTEURS sur chaque module : nouveaux invités/RSVP, demandes prestataires
//    traitées, paiements, livre d'or, galerie (« nouveau »), et à-traiter :
//    playlist, suggestions de menu, invités sans table, tâches dues
// ✅ Temps réel + remise à zéro à l'ouverture du module (synchronisée)
// ✅ Menu traiteur : section dédiée + stats + top plats + accès rapide
// ✅ Lit balancedSummaryProvider (partagé avec budget_page) → chiffres identiques
// ✅ Devise USD ($) partout
// ============================================================================
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/presentation/thix_weeding/pages/staff/models/thix_weeding_models.dart';
import 'package:thix_id/presentation/thix_weeding/pages/staff/providers/thix_weeding_providers.dart';
import 'package:thix_id/presentation/thix_weeding/pages/staff/budget/budget_page.dart'
    show balancedSummaryProvider, BalancedSummary;
import 'package:thix_id/presentation/thix_weeding/providers/wedding_badges.dart';

// ============================================================================
// DESIGN SYSTEM ROYAL
// ============================================================================
class _Royal {
  static const Color blue = Color(0xFF0B3B8F);
  static const Color purple = Color(0xFF6B46C1);
  static const Color gold = Color(0xFFD4AF37);
  static const Color goldDark = Color(0xFFB8860B);
  static const Color rose = Color(0xFFE31C4E);
  static const Color green = Color(0xFF059669);
  static const Color amber = Color(0xFFD97706);
  static const Color surface = Color(0xFFF8FAFC);
  static const Color card = Colors.white;
  static const Color text = Color(0xFF111827);
  static const Color text2 = Color(0xFF6B7280);
  static const Color border = Color(0xFFE5E7EB);

  static const LinearGradient royal = LinearGradient(
    colors: [blue, purple],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient goldG = LinearGradient(
    colors: [gold, goldDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient roseG = LinearGradient(
    colors: [rose, Color(0xFFFF6B9D)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient greenG = LinearGradient(
    colors: [green, Color(0xFF10B981)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static BoxDecoration cardBox({double radius = 16}) => BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      );
}

// ============================================================================
// ROUTES EXACTES (cf. thix_weeding_routes.dart)
// ============================================================================
class _Routes {
  static String _base(String id) => '/thix-weeding/staff/$id';
  static String invites(String id) => '${_base(id)}/invites';
  static String invitation(String id) => '${_base(id)}/invitation';
  static String prestataires(String id) => '${_base(id)}/prestataires';
  static String planning(String id) => '${_base(id)}/planning';
  static String checklist(String id) => '${_base(id)}/checklist';
  static String budget(String id) => '${_base(id)}/budget';
  static String paiements(String id) => '${_base(id)}/paiements';
  static String galerie(String id) => '${_base(id)}/galerie';
  static String livreOr(String id) => '${_base(id)}/livre-or';
  static String messages(String id) => '${_base(id)}/messages';
  static String parametres(String id) => '${_base(id)}/parametres';
  static String myWeddings() => '/thix-weeding/staff/my-weddings';
  static String seating(String id) => '${_base(id)}/seating';
  static String cadeaux(String id) => '${_base(id)}/cadeaux';
  static String playlist(String id) => '${_base(id)}/playlist';
  static String menu(String id) => '${_base(id)}/menu';
  static String info(String id, String kind) => '${_base(id)}/contenu/$kind';
}

// ============================================================================
// COMPTEURS SUPPLÉMENTAIRES
// ============================================================================
final _playlistPendingProvider =
    FutureProvider.autoDispose.family<int, String>((ref, weddingId) async {
  try {
    final r = await Supabase.instance.client
        .from('thix_weeding_playlist')
        .select('id')
        .eq('wedding_id', weddingId)
        .eq('status', 'pending');
    return (r as List).length;
  } catch (_) {
    return 0;
  }
});

final _menuCountProvider =
    FutureProvider.autoDispose.family<int, String>((ref, weddingId) async {
  try {
    final r = await Supabase.instance.client
        .from('thix_weeding_menu_items')
        .select('id')
        .eq('wedding_id', weddingId);
    return (r as List).length;
  } catch (_) {
    return 0;
  }
});

// Stats détaillées du menu
final _menuStatsProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, weddingId) async {
  try {
    final c = Supabase.instance.client;
    final items = await c
        .from('thix_weeding_menu_items')
        .select('*')
        .eq('wedding_id', weddingId);

    final total = (items as List).length;
    final validated = items.where((i) => i['is_validated'] == true).length;
    final public = items.where((i) => i['is_public'] == true).length;

    // Compter les votes
    final votes = await c
        .from('thix_weeding_menu_votes')
        .select('menu_item_id')
        .eq('wedding_id', weddingId);

    final voteCounts = <String, int>{};
    for (final v in votes) {
      final id = v['menu_item_id'] as String;
      voteCounts[id] = (voteCounts[id] ?? 0) + 1;
    }

    final totalVotes = voteCounts.values.fold(0, (s, v) => s + v);

    // Top 3 plats
    final topItems = items
        .map((i) => {
              'item': i,
              'votes': voteCounts[i['id'] as String] ?? 0,
            })
        .toList()
      ..sort((a, b) => (b['votes'] as int).compareTo(a['votes'] as int));

    return {
      'total': total,
      'validated': validated,
      'public': public,
      'totalVotes': totalVotes,
      'top3': topItems.take(3).where((t) => (t['votes'] as int) > 0).toList(),
    };
  } catch (e) {
    return {
      'total': 0,
      'validated': 0,
      'public': 0,
      'totalVotes': 0,
      'top3': [],
    };
  }
});

// ============================================================================
// PAGE PRINCIPALE
// ============================================================================
class StaffDashboardPage extends ConsumerStatefulWidget {
  final String weddingId;
  const StaffDashboardPage({super.key, required this.weddingId});

  @override
  ConsumerState<StaffDashboardPage> createState() => _StaffDashboardPageState();
}

class _StaffDashboardPageState extends ConsumerState<StaffDashboardPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _anim.forward();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final id = widget.weddingId;
    ref.invalidate(weddingProvider(id));
    ref.invalidate(guestsProvider(id));
    ref.invalidate(vendorsProvider(id));
    ref.invalidate(checklistProvider(id));
    ref.invalidate(galleryProvider(id));
    ref.invalidate(guestbookProvider(id));
    ref.invalidate(messagesProvider(id));
    ref.invalidate(paymentsProvider(id));
    ref.invalidate(budgetProvider(id));
    ref.invalidate(expensesProvider(id));
    ref.invalidate(dashboardStatsProvider(id));
    ref.invalidate(paymentsSummaryProvider(id));
    ref.invalidate(balancedSummaryProvider(id));
    ref.invalidate(_playlistPendingProvider(id));
    ref.invalidate(_menuCountProvider(id));
    ref.invalidate(_menuStatsProvider(id));
    ref.invalidate(weddingBadgesProvider((weddingId: id, role: 'staff')));
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.weddingId;
    final weddingAsync = ref.watch(weddingProvider(id));

    return Scaffold(
      backgroundColor: _Royal.surface,
      body: weddingAsync.when(
        loading: () => const _LoadingView(),
        error: (e, _) => _ErrorView(message: '$e', onRetry: _refresh),
        data: (wedding) {
          final guests = ref.watch(guestsProvider(id)).valueOrNull ?? const [];
          final vendors = ref.watch(vendorsProvider(id)).valueOrNull ?? const [];
          final tasks = ref.watch(checklistProvider(id)).valueOrNull ?? const [];
          final gallery = ref.watch(galleryProvider(id)).valueOrNull ?? const [];
          final guestbook = ref.watch(guestbookProvider(id)).valueOrNull ?? const [];
          final messages = ref.watch(messagesProvider(id)).valueOrNull ?? const [];
          final payments = ref.watch(paymentsProvider(id)).valueOrNull ?? const [];
          final budget = ref.watch(budgetProvider(id)).valueOrNull;
          final balanced = ref.watch(balancedSummaryProvider(id)).valueOrNull;
          final playlistPending = ref.watch(_playlistPendingProvider(id)).valueOrNull ?? 0;
          final menuCount = ref.watch(_menuCountProvider(id)).valueOrNull ?? 0;
          final menuStats = ref.watch(_menuStatsProvider(id)).valueOrNull ?? {};
          final badges = ref
                  .watch(weddingBadgesProvider((weddingId: id, role: 'staff')))
                  .valueOrNull ??
              WeddingBadges.empty;

          final unread = messages.where((m) => !m.isRead && m.senderType == 'guest').length;

          return FadeTransition(
            opacity: _fade,
            child: RefreshIndicator(
              color: _Royal.blue,
              onRefresh: _refresh,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  _RoyalAppBar(
                    wedding: wedding,
                    unread: unread,
                    onMessages: () => context.push(_Routes.messages(id)),
                    onSettings: () => context.push(_Routes.parametres(id)),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _HeroBanner(
                            wedding: wedding,
                            coverUrl: gallery.isNotEmpty ? gallery.first.imageUrl : null),
                        const SizedBox(height: 16),
                        _StatsRow(guests: guests, vendors: vendors, tasks: tasks),
                        const SizedBox(height: 16),
                        _RsvpCard(guests: guests),
                        const SizedBox(height: 16),
                        _BudgetCard(
                          totalBudget: budget?.totalBudget ?? 0,
                          summary: balanced,
                          onTap: () => context.push(_Routes.budget(id)),
                        ),

                        // Section Menu & Traiteur
                        if (menuCount > 0) ...[
                          const SizedBox(height: 24),
                          _SectionTitle('Menu & Traiteur',
                              icon: Icons.restaurant_menu_outlined,
                              actionLabel: 'Gérer',
                              onAction: () => context.push(_Routes.menu(id))),
                          const SizedBox(height: 12),
                          _MenuCard(
                            weddingId: id,
                            stats: menuStats,
                            onTap: () => context.push(_Routes.menu(id)),
                          ),
                        ],

                        const SizedBox(height: 24),
                        _SectionTitle('Tous les modules', icon: Icons.apps),
                        const SizedBox(height: 12),
                        _ModulesGrid(
                          weddingId: id,
                          wedding: wedding,
                          guestExperience: false,
                          guestsCount: guests.length,
                          vendorsBooked: vendors.where((v) => v.isBooked).length,
                          pendingTasks: tasks.where((t) => !t.isDone).length,
                          photosCount: gallery.length,
                          guestbookCount: guestbook.where((g) => g.isApproved).length,
                          unreadMessages: unread,
                          playlistPending: playlistPending,
                          menuCount: menuCount,
                          badges: badges,
                        ),
                        const SizedBox(height: 24),
                        _SectionTitle('Expérience des invités', icon: Icons.celebration_outlined),
                        const SizedBox(height: 4),
                        Text('Ce que vos invités voient sur leur accueil',
                            style: GoogleFonts.inter(fontSize: 11.5, color: _Royal.text2)),
                        const SizedBox(height: 12),
                        _ModulesGrid(
                          weddingId: id,
                          wedding: wedding,
                          guestExperience: true,
                          guestsCount: guests.length,
                          vendorsBooked: vendors.where((v) => v.isBooked).length,
                          pendingTasks: tasks.where((t) => !t.isDone).length,
                          photosCount: gallery.length,
                          guestbookCount: guestbook.where((g) => g.isApproved).length,
                          unreadMessages: unread,
                          playlistPending: playlistPending,
                          menuCount: menuCount,
                          badges: badges,
                        ),
                        const SizedBox(height: 24),
                        _SectionTitle('Checklist préparatifs',
                            icon: Icons.checklist_outlined,
                            actionLabel: 'Voir tout',
                            onAction: () => context.push(_Routes.checklist(id))),
                        const SizedBox(height: 12),
                        _ChecklistCard(tasks: tasks),
                        const SizedBox(height: 24),
                        _SectionTitle('Galerie souvenirs',
                            icon: Icons.photo_library_outlined,
                            actionLabel: 'Gérer',
                            onAction: () => context.push(_Routes.galerie(id))),
                        const SizedBox(height: 12),
                        _GalleryStrip(gallery: gallery, weddingId: id),
                        const SizedBox(height: 24),
                        _SectionTitle('Prestataires',
                            icon: Icons.storefront_outlined,
                            actionLabel: 'Voir tout',
                            onAction: () => context.push(_Routes.prestataires(id))),
                        const SizedBox(height: 12),
                        _VendorsCard(vendors: vendors),
                        const SizedBox(height: 24),
                        _SectionTitle('Paiements récents',
                            icon: Icons.payments_outlined,
                            actionLabel: 'Voir tout',
                            onAction: () => context.push(_Routes.paiements(id))),
                        const SizedBox(height: 12),
                        _PaymentsCard(payments: payments),
                        const SizedBox(height: 24),
                        _SectionTitle("Livre d'or",
                            icon: Icons.menu_book_outlined,
                            actionLabel: 'Modérer',
                            onAction: () => context.push(_Routes.livreOr(id))),
                        const SizedBox(height: 12),
                        _GuestbookCard(entries: guestbook),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// Carte Menu & Traiteur
class _MenuCard extends StatelessWidget {
  final String weddingId;
  final Map<String, dynamic> stats;
  final VoidCallback onTap;

  const _MenuCard({
    required this.weddingId,
    required this.stats,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final total = stats['total'] as int? ?? 0;
    final validated = stats['validated'] as int? ?? 0;
    final public = stats['public'] as int? ?? 0;
    final totalVotes = stats['totalVotes'] as int? ?? 0;
    final top3 = (stats['top3'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: _Royal.cardBox(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: _Royal.goldG,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.restaurant_menu, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Menu du mariage',
                            style: GoogleFonts.inter(
                                fontSize: 15, fontWeight: FontWeight.w700)),
                        Text('$total plat${total > 1 ? 's' : ''} • $totalVotes vote${totalVotes > 1 ? 's' : ''}',
                            style: GoogleFonts.inter(fontSize: 11, color: _Royal.text2)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: _Royal.text2),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _MenuStatChip(label: 'Total', value: '$total', color: _Royal.blue),
                  const SizedBox(width: 8),
                  _MenuStatChip(label: 'Validés', value: '$validated', color: _Royal.green),
                  const SizedBox(width: 8),
                  _MenuStatChip(label: 'Publics', value: '$public', color: _Royal.purple),
                  const SizedBox(width: 8),
                  _MenuStatChip(label: 'Votes', value: '$totalVotes', color: _Royal.gold),
                ],
              ),
              if (top3.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_Royal.gold.withOpacity(0.1), _Royal.gold.withOpacity(0.05)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _Royal.gold.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.emoji_events, size: 16, color: _Royal.gold),
                          const SizedBox(width: 6),
                          Text('Top 3 des plats',
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: _Royal.gold)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ...top3.asMap().entries.map((entry) {
                        final i = entry.key;
                        final data = entry.value;
                        final item = data['item'] as Map<String, dynamic>;
                        final votes = data['votes'] as int;
                        final name = item['name'] as String? ?? 'Sans nom';

                        return Padding(
                          padding: EdgeInsets.only(bottom: i < top3.length - 1 ? 8 : 0),
                          child: Row(
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: i == 0 ? _Royal.gold : (i == 1 ? Colors.grey.shade400 : Colors.brown.shade400),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text('${i + 1}',
                                      style: GoogleFonts.inter(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white)),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                        fontSize: 12, fontWeight: FontWeight.w600)),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: _Royal.rose.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.favorite, size: 11, color: _Royal.rose),
                                    const SizedBox(width: 3),
                                    Text('$votes',
                                        style: GoogleFonts.inter(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            color: _Royal.rose)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuStatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MenuStatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(value,
                style: GoogleFonts.inter(
                    fontSize: 16, fontWeight: FontWeight.w900, color: color)),
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 9, color: color.withOpacity(0.8), fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// APP BAR
// ============================================================================
class _RoyalAppBar extends StatelessWidget {
  final WeddingModel wedding;
  final int unread;
  final VoidCallback onMessages;
  final VoidCallback onSettings;

  const _RoyalAppBar(
      {required this.wedding,
      required this.unread,
      required this.onMessages,
      required this.onSettings});

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      floating: true,
      snap: true,
      backgroundColor: Colors.white,
      elevation: 0,
      foregroundColor: _Royal.text,
      title: Text('Dashboard',
          style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: _Royal.blue)),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: wedding.invitationPublished
                ? _Royal.green.withOpacity(0.1)
                : _Royal.amber.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(
                wedding.invitationPublished
                    ? Icons.verified
                    : Icons.hourglass_bottom,
                size: 12,
                color: wedding.invitationPublished ? _Royal.green : _Royal.amber),
            const SizedBox(width: 4),
            Text(wedding.invitationPublished ? 'Publiée' : 'Brouillon',
                style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: wedding.invitationPublished ? _Royal.green : _Royal.amber)),
          ]),
        ),
        Stack(clipBehavior: Clip.none, children: [
          IconButton(icon: const Icon(Icons.chat_bubble_outline), onPressed: onMessages),
          if (unread > 0)
            Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                      color: _Royal.rose,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2)),
                  child: Text('$unread',
                      style: GoogleFonts.inter(
                          fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white)),
                )),
        ]),
        IconButton(icon: const Icon(Icons.settings_outlined), onPressed: onSettings),
        const SizedBox(width: 4),
      ],
    );
  }
}

// ============================================================================
// HERO BANNER + COUNTDOWN LIVE
// ============================================================================
class _HeroBanner extends StatelessWidget {
  final WeddingModel wedding;
  final String? coverUrl;
  const _HeroBanner({required this.wedding, this.coverUrl});

  @override
  Widget build(BuildContext context) {
    final date = wedding.weddingDate;
    return Container(
      height: 300,
      decoration: _Royal.cardBox(radius: 24),
      clipBehavior: Clip.antiAlias,
      child: Stack(fit: StackFit.expand, children: [
        if (coverUrl != null && coverUrl!.isNotEmpty)
          Image.network(coverUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const _MonogramFallback(),
              loadingBuilder: (_, child, progress) =>
                  progress == null ? child : const _MonogramFallback())
        else
          const _MonogramFallback(),
        DecoratedBox(
            decoration: BoxDecoration(
                gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.15),
            Colors.black.withOpacity(0.55),
            const Color(0xFF061F47).withOpacity(0.92)
          ],
          stops: const [0.0, 0.55, 1.0],
        ))),
        Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Row(children: [
                  Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                          color: _Royal.gold.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _Royal.gold.withOpacity(0.6))),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.qr_code_2, size: 12, color: _Royal.gold),
                        const SizedBox(width: 6),
                        Text(wedding.uniqueCode,
                            style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: _Royal.gold,
                                letterSpacing: 1.2)),
                      ])),
                  const Spacer(),
                  if (date != null) _JBadge(date: date),
                ]),
                const SizedBox(height: 12),
                Text(
                    wedding.coupleNames.isEmpty ? 'Notre Mariage' : wedding.coupleNames,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.15)),
                const SizedBox(height: 6),
                Row(children: [
                  const Icon(Icons.place_outlined, size: 14, color: Colors.white70),
                  const SizedBox(width: 4),
                  Expanded(
                      child: Text(
                    [
                      if (wedding.venue != null && wedding.venue!.isNotEmpty)
                        wedding.venue!,
                      if (date != null) _fmtDate(date)
                    ].join('  •  '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.white70))),
                ]),
                const SizedBox(height: 16),
                if (date != null) _LiveCountdown(target: date),
              ],
            )),
      ]),
    );
  }
}

class _JBadge extends StatelessWidget {
  final DateTime date;
  const _JBadge({required this.date});

  @override
  Widget build(BuildContext context) {
    final days = date.difference(DateTime.now()).inDays;
    final isToday = DateTime.now().day == date.day &&
        DateTime.now().month == date.month &&
        DateTime.now().year == date.year;
    final isPast = date.isBefore(DateTime.now()) && !isToday;
    final label = isPast ? 'CÉLÉBRÉ ✨' : (isToday ? "JOUR J 💍" : 'J − $days');
    final gradient = isPast ? _Royal.greenG : (isToday ? _Royal.roseG : _Royal.goldG);
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(gradient: gradient, borderRadius: BorderRadius.circular(8)),
        child: Text(label,
            style: GoogleFonts.inter(
                fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white)));
  }
}

class _LiveCountdown extends StatefulWidget {
  final DateTime target;
  const _LiveCountdown({required this.target});
  @override
  State<_LiveCountdown> createState() => _LiveCountdownState();
}

class _LiveCountdownState extends State<_LiveCountdown> {
  Timer? _timer;
  late Duration _left;

  @override
  void initState() {
    super.initState();
    _left = widget.target.difference(DateTime.now());
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _left = widget.target.difference(DateTime.now()));
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_left.isNegative) {
      return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(gradient: _Royal.greenG, borderRadius: BorderRadius.circular(12)),
          child: Text('🎉 Mariage célébré — revivez les souvenirs',
              style: GoogleFonts.inter(
                  fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)));
    }
    return Row(children: [
      _TimeCell(value: _left.inDays, label: 'JOURS'),
      _TimeSep(),
      _TimeCell(value: _left.inHours % 24, label: 'HEURES'),
      _TimeSep(),
      _TimeCell(value: _left.inMinutes % 60, label: 'MIN'),
      _TimeSep(),
      _TimeCell(value: _left.inSeconds % 60, label: 'SEC'),
    ]);
  }
}

class _TimeCell extends StatelessWidget {
  final int value;
  final String label;
  const _TimeCell({required this.value, required this.label});
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.14),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.25))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(value.toString().padLeft(2, '0'),
            style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                fontFeatures: const [FontFeature.tabularFigures()])),
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 8,
                fontWeight: FontWeight.w700,
                color: Colors.white70,
                letterSpacing: 1)),
      ]));
}

class _TimeSep extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Text(':',
          style: GoogleFonts.inter(
              fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white54)));
}

class _MonogramFallback extends StatelessWidget {
  const _MonogramFallback();
  @override
  Widget build(BuildContext context) => Container(
      decoration: const BoxDecoration(gradient: _Royal.royal),
      child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _Royal.gold.withOpacity(0.7), width: 2)),
            child: const Icon(Icons.favorite, color: _Royal.gold, size: 40)),
        const SizedBox(height: 10),
        Text('THIX WEDDING',
            style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Colors.white54,
                letterSpacing: 3)),
      ])));
}

// ============================================================================
// STATS ROW
// ============================================================================
class _StatsRow extends StatelessWidget {
  final List<GuestModel> guests;
  final List<VendorModel> vendors;
  final List<ChecklistModel> tasks;
  const _StatsRow({required this.guests, required this.vendors, required this.tasks});

  @override
  Widget build(BuildContext context) {
    final totalSeats = guests.fold<int>(0, (s, g) => s + g.guestsCount);
    final present = guests.where((g) => g.isPresent).fold<int>(0, (s, g) => s + g.guestsCount);
    final done = tasks.where((t) => t.isDone).length;
    return Row(children: [
      Expanded(child: _StatCard(label: 'Invités', value: '$totalSeats', icon: Icons.people, gradient: _Royal.royal)),
      const SizedBox(width: 10),
      Expanded(child: _StatCard(label: 'Présents', value: '$present', icon: Icons.check_circle, gradient: _Royal.greenG)),
      const SizedBox(width: 10),
      Expanded(child: _StatCard(label: 'Prestat.', value: '${vendors.length}', icon: Icons.storefront, gradient: _Royal.goldG)),
      const SizedBox(width: 10),
      Expanded(child: _StatCard(label: 'Tâches', value: '$done/${tasks.length}', icon: Icons.task_alt, gradient: _Royal.roseG)),
    ]);
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final LinearGradient gradient;
  const _StatCard({required this.label, required this.value, required this.icon, required this.gradient});

  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: _Royal.cardBox(radius: 14),
      child: Column(children: [
        Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(gradient: gradient, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: Colors.white, size: 16)),
        const SizedBox(height: 8),
        Text(value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: _Royal.text)),
        Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(fontSize: 10, color: _Royal.text2)),
      ]));
}

// ============================================================================
// RSVP CARD
// ============================================================================
class _RsvpCard extends StatelessWidget {
  final List<GuestModel> guests;
  const _RsvpCard({required this.guests});

  @override
  Widget build(BuildContext context) {
    final confirmed = guests.where((g) => g.rsvpStatus == 'confirmed' || g.rsvpStatus == 'accepted').length;
    final declined = guests.where((g) => g.rsvpStatus == 'declined').length;
    final pending = guests.length - confirmed - declined;
    final total = guests.isEmpty ? 1 : guests.length;

    return Container(
        padding: const EdgeInsets.all(16),
        decoration: _Royal.cardBox(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.mark_email_read_outlined, size: 18, color: _Royal.blue),
            const SizedBox(width: 8),
            Text('Confirmations RSVP',
                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 14),
          ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                  minHeight: 10,
                  value: confirmed / total,
                  backgroundColor: _Royal.rose.withOpacity(0.15),
                  valueColor: const AlwaysStoppedAnimation(_Royal.green))),
          const SizedBox(height: 12),
          Row(children: [
            _RsvpChip(label: 'Confirmés', count: confirmed, color: _Royal.green),
            const SizedBox(width: 8),
            _RsvpChip(label: 'En attente', count: pending, color: _Royal.amber),
            const SizedBox(width: 8),
            _RsvpChip(label: 'Déclinés', count: declined, color: _Royal.rose),
          ]),
        ]));
  }
}

class _RsvpChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _RsvpChip({required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
      child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
          child: Column(children: [
            Text('$count', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: color)),
            Text(label, style: GoogleFonts.inter(fontSize: 10, color: color.withOpacity(0.9))),
          ])));
}

// ============================================================================
// BUDGET CARD
// ============================================================================
class _BudgetCard extends StatelessWidget {
  final double totalBudget;
  final BalancedSummary? summary;
  final VoidCallback onTap;

  const _BudgetCard({
    required this.totalBudget,
    required this.summary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (totalBudget <= 0) {
      return Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: _Royal.cardBox(),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(gradient: _Royal.goldG, shape: BoxShape.circle),
                child: const Icon(Icons.account_balance_wallet_outlined, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Budget', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text('Aucun budget défini — appuyez pour créer',
                      style: GoogleFonts.inter(fontSize: 12, color: _Royal.text2)),
                ]),
              ),
              const Icon(Icons.chevron_right, color: _Royal.text2),
            ]),
          ),
        ),
      );
    }

    final spent = summary?.spent ?? 0.0;
    final paid = summary?.paid ?? 0.0;
    final remaining = summary?.remaining ?? totalBudget;
    final debt = summary?.debt ?? 0.0;

    final cashRatio = totalBudget > 0 ? (paid / totalBudget).clamp(0.0, 1.0) : 0.0;
    final commitRatio = totalBudget > 0 ? (spent / totalBudget).clamp(0.0, 1.0) : 0.0;
    final over = paid > totalBudget || spent > totalBudget;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: _Royal.cardBox(),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.account_balance_wallet_outlined, size: 18, color: _Royal.blue),
              const SizedBox(width: 8),
              Text('Budget (USD)', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                    gradient: over ? _Royal.roseG : _Royal.goldG,
                    borderRadius: BorderRadius.circular(8)),
                child: Text('${(cashRatio * 100).toStringAsFixed(0)}%',
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white)),
              ),
            ]),
            const SizedBox(height: 6),
            Text('Budget global : ${_fmtMoney(totalBudget)}',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: _Royal.text2)),
            const SizedBox(height: 10),
            ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                    minHeight: 10,
                    value: cashRatio,
                    backgroundColor: _Royal.border,
                    valueColor: AlwaysStoppedAnimation(over ? _Royal.rose : _Royal.green))),
            const SizedBox(height: 5),
            ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                    minHeight: 4,
                    value: commitRatio,
                    backgroundColor: _Royal.border.withOpacity(0.6),
                    valueColor: AlwaysStoppedAnimation(_Royal.blue.withOpacity(0.55)))),
            const SizedBox(height: 5),
            Row(children: [
              Text('Décaissé ${(cashRatio * 100).toStringAsFixed(1)}%',
                  style: GoogleFonts.inter(fontSize: 9.5, color: _Royal.text2)),
              const SizedBox(width: 12),
              Text('Engagé ${(commitRatio * 100).toStringAsFixed(1)}%',
                  style: GoogleFonts.inter(fontSize: 9.5, color: _Royal.text2.withOpacity(0.8))),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              _MoneyCell(label: 'Dépensé', value: spent, color: _Royal.rose),
              _MoneyCell(label: 'Payé', value: paid, color: _Royal.blue),
              _MoneyCell(
                label: over ? 'Dépassement' : 'Restant',
                value: remaining.abs(),
                color: over ? _Royal.rose : _Royal.green,
              ),
            ]),
            if (debt > 0) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: _Royal.amber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _Royal.amber.withOpacity(0.4)),
                ),
                child: Row(children: [
                  const Icon(Icons.warning_amber_rounded, size: 14, color: _Royal.amber),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Dette prestataires : ${_fmtMoney(debt)}',
                        style: GoogleFonts.inter(
                            fontSize: 11, fontWeight: FontWeight.w700, color: _Royal.amber)),
                  ),
                ]),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}

class _MoneyCell extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _MoneyCell({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: GoogleFonts.inter(fontSize: 10, color: _Royal.text2)),
        const SizedBox(height: 2),
        Text(_fmtMoney(value),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: color)),
      ]));
}

// ============================================================================
// MODULES GRID — compteurs « nouveau / à traiter » sur chaque module
// ============================================================================
class _ModulesGrid extends StatelessWidget {
  final String weddingId;
  final WeddingModel wedding;
  final bool guestExperience;
  final int guestsCount;
  final int vendorsBooked;
  final int pendingTasks;
  final int photosCount;
  final int guestbookCount;
  final int unreadMessages;
  final int playlistPending;
  final int menuCount;
  final WeddingBadges badges;

  const _ModulesGrid({
    required this.weddingId,
    required this.wedding,
    required this.guestExperience,
    required this.guestsCount,
    required this.vendorsBooked,
    required this.pendingTasks,
    required this.photosCount,
    required this.guestbookCount,
    required this.unreadMessages,
    required this.playlistPending,
    required this.menuCount,
    required this.badges,
  });

  @override
  Widget build(BuildContext context) {
    final id = weddingId;

    final core = <_Module>[
      _Module('Invités', '$guestsCount', Icons.people_outline, _Royal.royal, _Routes.invites(id),
          feature: 'invites', badge: badges.of('invites')),
      _Module('Invitation', wedding.invitationPublished ? 'Publiée' : 'Brouillon', Icons.mail_outline, _Royal.roseG, _Routes.invitation(id)),
      _Module('Prestataires', '$vendorsBooked réservés', Icons.storefront_outlined, _Royal.goldG, _Routes.prestataires(id),
          feature: 'prestataires', badge: badges.of('prestataires')),
      _Module('Planning', 'Jour J', Icons.schedule_outlined, _Royal.royal, _Routes.planning(id)),
      _Module('Checklist', '$pendingTasks restantes', Icons.checklist_outlined, _Royal.greenG, _Routes.checklist(id),
          feature: 'checklist', badge: badges.of('checklist')),
      _Module('Budget', 'Suivi USD', Icons.account_balance_wallet_outlined, _Royal.goldG, _Routes.budget(id)),
      _Module('Paiements', 'Transactions', Icons.payments_outlined, _Royal.greenG, _Routes.paiements(id),
          feature: 'paiements', badge: badges.of('paiements')),
      _Module('Galerie', '$photosCount photos', Icons.photo_library_outlined, _Royal.roseG, _Routes.galerie(id),
          feature: 'galerie', badge: badges.of('galerie')),
      _Module("Livre d'or", '$guestbookCount msgs', Icons.menu_book_outlined, _Royal.goldG, _Routes.livreOr(id),
          feature: 'livre-or', badge: badges.of('livre-or')),
      _Module('Messages', unreadMessages > 0 ? '$unreadMessages nouveaux' : 'À jour', Icons.chat_bubble_outline, _Royal.royal, _Routes.messages(id),
          feature: 'messages', badge: unreadMessages),
      _Module('Plan de table', 'Salle 3D', Icons.table_restaurant_outlined, _Royal.goldG, _Routes.seating(id),
          feature: 'seating', badge: badges.of('seating')),
      _Module('Cadeaux', 'Propositions', Icons.card_giftcard_outlined, _Royal.roseG, _Routes.cadeaux(id)),
      _Module('Paramètres', 'Réglages', Icons.settings_outlined, LinearGradient(colors: [Colors.grey.shade600, Colors.grey.shade800]), _Routes.parametres(id)),
      _Module('Mes mariages', 'Multi-événements', Icons.favorite_border, _Royal.roseG, _Routes.myWeddings()),
    ];

    final menuPending = badges.of('menu');
    final guestMods = <_Module>[
      _Module('Playlist', playlistPending > 0 ? '$playlistPending à valider' : 'Musique', Icons.queue_music_rounded, _Royal.roseG, _Routes.playlist(id),
          feature: 'playlist', badge: playlistPending),
      _Module('Menu', menuPending > 0 ? '$menuPending suggestion${menuPending > 1 ? 's' : ''}' : (menuCount > 0 ? '$menuCount plats' : 'Repas'),
          Icons.restaurant_menu_rounded, _Royal.goldG, _Routes.menu(id),
          feature: 'menu', badge: menuPending),
      _Module('Navette', 'Transport', Icons.directions_bus_outlined, _Royal.royal, _Routes.info(id, 'navette')),
      _Module('Dress code', 'Tenue', Icons.checkroom_outlined, _Royal.roseG, _Routes.info(id, 'dress_code')),
      _Module('FAQ', 'Questions', Icons.help_outline_rounded, _Royal.greenG, _Routes.info(id, 'faq')),
      _Module('Remerciements', 'Un mot', Icons.volunteer_activism_outlined, _Royal.goldG, _Routes.info(id, 'thanks')),
      _Module('Live', 'En direct', Icons.podcasts_outlined, _Royal.royal, _Routes.info(id, 'live')),
    ];

    final modules = guestExperience ? guestMods : core;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 0.92),
      itemCount: modules.length,
      itemBuilder: (_, i) => _ModuleTile(weddingId: weddingId, module: modules[i]),
    );
  }
}

class _Module {
  final String title;
  final String subtitle;
  final IconData icon;
  final LinearGradient gradient;
  final String route;
  final int badge;

  /// Clé du compteur (remise à zéro à l'ouverture). null = pas de compteur.
  final String? feature;
  _Module(this.title, this.subtitle, this.icon, this.gradient, this.route,
      {this.badge = 0, this.feature});
}

class _ModuleTile extends ConsumerWidget {
  final String weddingId;
  final _Module module;
  const _ModuleTile({required this.weddingId, required this.module});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () {
          final f = module.feature;
          if (f != null) {
            unawaited(markWeddingSeen(ref, weddingId: weddingId, role: 'staff', feature: f));
          }
          context.push(module.route);
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
            padding: const EdgeInsets.all(10),
            decoration: _Royal.cardBox(radius: 16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Stack(clipBehavior: Clip.none, children: [
                    Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(gradient: module.gradient, borderRadius: BorderRadius.circular(10)),
                        child: Icon(module.icon, color: Colors.white, size: 18)),
                    if (module.badge > 0)
                      Positioned(
                          right: -6,
                          top: -6,
                          child: Container(
                              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                  color: _Royal.rose,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.white, width: 2)),
                              child: Text(module.badge > 99 ? '99+' : '${module.badge}',
                                  style: GoogleFonts.inter(
                                      fontSize: 8.5, fontWeight: FontWeight.w800, color: Colors.white)))),
                  ]),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(module.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: _Royal.text)),
                    const SizedBox(height: 2),
                    Text(module.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(fontSize: 9, color: _Royal.text2)),
                  ]),
                ])),
      ));
}

// ============================================================================
// CHECKLIST CARD
// ============================================================================
class _ChecklistCard extends StatelessWidget {
  final List<ChecklistModel> tasks;
  const _ChecklistCard({required this.tasks});

  @override
  Widget build(BuildContext context) {
    final done = tasks.where((t) => t.isDone).length;
    final ratio = tasks.isEmpty ? 0.0 : done / tasks.length;
    final upcoming = [...tasks]
      ..removeWhere((t) => t.isDone)
      ..sort((a, b) {
        if (a.dueDate == null && b.dueDate == null) return 0;
        if (a.dueDate == null) return 1;
        if (b.dueDate == null) return -1;
        return a.dueDate!.compareTo(b.dueDate!);
      });

    return Container(
        padding: const EdgeInsets.all(16),
        decoration: _Royal.cardBox(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            SizedBox(
                width: 44,
                height: 44,
                child: Stack(alignment: Alignment.center, children: [
                  SizedBox(
                      width: 44,
                      height: 44,
                      child: CircularProgressIndicator(
                          value: ratio,
                          strokeWidth: 5,
                          backgroundColor: _Royal.border,
                          valueColor: const AlwaysStoppedAnimation(_Royal.green))),
                  Text('${(ratio * 100).toStringAsFixed(0)}%',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: _Royal.text)),
                ])),
            const SizedBox(width: 12),
            Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$done / ${tasks.length} tâches accomplies',
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700)),
              Text(upcoming.isEmpty ? 'Tout est prêt 🎉' : 'Prochaine : ${upcoming.first.title}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(fontSize: 12, color: _Royal.text2)),
            ])),
          ]),
          if (upcoming.isNotEmpty) ...[
            const SizedBox(height: 14),
            ...upcoming.take(3).map((t) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                          color: t.dueDate != null && t.dueDate!.isBefore(DateTime.now())
                              ? _Royal.rose
                              : _Royal.amber,
                          shape: BoxShape.circle)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text(t.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600))),
                  if (t.dueDate != null)
                    Text(
                        '${t.dueDate!.day.toString().padLeft(2, '0')}/${t.dueDate!.month.toString().padLeft(2, '0')}',
                        style: GoogleFonts.inter(fontSize: 11, color: _Royal.text2)),
                ]))),
          ],
        ]));
  }
}

// ============================================================================
// GALLERY STRIP
// ============================================================================
class _GalleryStrip extends StatelessWidget {
  final List<GalleryModel> gallery;
  final String weddingId;
  const _GalleryStrip({required this.gallery, required this.weddingId});

  @override
  Widget build(BuildContext context) {
    if (gallery.isEmpty) {
      return Container(
          padding: const EdgeInsets.all(20),
          decoration: _Royal.cardBox(),
          child: Column(children: [
            const Icon(Icons.photo_camera_outlined, size: 36, color: _Royal.text2),
            const SizedBox(height: 8),
            Text('Aucune photo pour le moment',
                style: GoogleFonts.inter(fontSize: 13, color: _Royal.text2)),
            const SizedBox(height: 12),
            FilledButton.icon(
                onPressed: () => context.push(_Routes.galerie(weddingId)),
                icon: const Icon(Icons.add_a_photo_outlined, size: 16),
                label: const Text('Ajouter des photos'),
                style: FilledButton.styleFrom(backgroundColor: _Royal.blue)),
          ]));
    }
    return SizedBox(
        height: 130,
        child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: gallery.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) => ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.network(gallery[i].imageUrl,
                    width: 130,
                    height: 130,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                        width: 130,
                        height: 130,
                        color: _Royal.border,
                        child: const Icon(Icons.broken_image_outlined, color: _Royal.text2))))));
  }
}

// ============================================================================
// VENDORS CARD
// ============================================================================
class _VendorsCard extends StatelessWidget {
  final List<VendorModel> vendors;
  const _VendorsCard({required this.vendors});

  @override
  Widget build(BuildContext context) {
    if (vendors.isEmpty) return _EmptyCard(message: 'Aucun prestataire engagé', icon: Icons.storefront_outlined);
    final booked = vendors.where((v) => v.isBooked).toList();
    final shown = (booked + vendors.where((v) => !v.isBooked).toList()).take(3);
    return Container(
        padding: const EdgeInsets.all(16),
        decoration: _Royal.cardBox(),
        child: Column(
            children: shown
                .map((v) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(children: [
                      Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                              gradient: v.isBooked ? _Royal.greenG : _Royal.goldG,
                              borderRadius: BorderRadius.circular(10)),
                          child: Icon(v.isBooked ? Icons.verified : Icons.hourglass_bottom,
                              color: Colors.white, size: 16)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(v.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700)),
                        Text(v.category,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(fontSize: 11, color: _Royal.text2)),
                      ])),
                      if (v.price != null)
                        Text(_fmtMoney(v.price!),
                            style: GoogleFonts.inter(
                                fontSize: 12, fontWeight: FontWeight.w700, color: _Royal.blue)),
                    ])))
                .toList()));
  }
}

// ============================================================================
// PAYMENTS CARD
// ============================================================================
class _PaymentsCard extends StatelessWidget {
  final List<PaymentModel> payments;
  const _PaymentsCard({required this.payments});

  @override
  Widget build(BuildContext context) {
    if (payments.isEmpty) return _EmptyCard(message: 'Aucun paiement enregistré', icon: Icons.payments_outlined);
    return Container(
        padding: const EdgeInsets.all(16),
        decoration: _Royal.cardBox(),
        child: Column(
            children: payments.take(3).map((p) {
          final ok = p.status == 'completed';
          return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(children: [
                Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                        color: (ok ? _Royal.green : _Royal.amber).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10)),
                    child: Icon(ok ? Icons.check_circle_outline : Icons.schedule,
                        color: ok ? _Royal.green : _Royal.amber, size: 16)),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p.vendorName ?? p.expenseTitle ?? 'Paiement',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700)),
                  Text('${p.method} • ${p.createdAt.day.toString().padLeft(2, '0')}/${p.createdAt.month.toString().padLeft(2, '0')}',
                      style: GoogleFonts.inter(fontSize: 11, color: _Royal.text2)),
                ])),
                Text(_fmtMoney(p.amount),
                    style: GoogleFonts.inter(
                        fontSize: 13, fontWeight: FontWeight.w800, color: ok ? _Royal.green : _Royal.amber)),
              ]));
        }).toList()));
  }
}

// ============================================================================
// GUESTBOOK CARD
// ============================================================================
class _GuestbookCard extends StatelessWidget {
  final List<GuestbookModel> entries;
  const _GuestbookCard({required this.entries});

  @override
  Widget build(BuildContext context) {
    final approved = entries.where((e) => e.isApproved).toList();
    if (approved.isEmpty) return _EmptyCard(message: 'Aucun message approuvé', icon: Icons.menu_book_outlined);
    return Container(
        padding: const EdgeInsets.all(16),
        decoration: _Royal.cardBox(),
        child: Column(
            children: approved.take(2).map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(gradient: _Royal.roseG, borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.format_quote, color: Colors.white, size: 16)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(e.message,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(fontSize: 13, fontStyle: FontStyle.italic)),
                    const SizedBox(height: 4),
                    Text('— ${e.guestName}',
                        style: GoogleFonts.inter(
                            fontSize: 11, fontWeight: FontWeight.w700, color: _Royal.rose)),
                  ])),
                ]))).toList()));
  }
}

// ============================================================================
// UTILITAIRES
// ============================================================================
class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  const _SectionTitle(this.title, {required this.icon, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 18, color: _Royal.blue),
        const SizedBox(width: 8),
        Expanded(
            child: Text(title,
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: _Royal.text))),
        if (actionLabel != null && onAction != null)
          GestureDetector(
              onTap: onAction,
              child: Text(actionLabel!,
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: _Royal.blue))),
      ]);
}

class _EmptyCard extends StatelessWidget {
  final String message;
  final IconData icon;
  const _EmptyCard({required this.message, required this.icon});

  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(20),
      decoration: _Royal.cardBox(),
      child: Column(children: [
        Icon(icon, size: 32, color: _Royal.text2),
        const SizedBox(height: 8),
        Text(message, style: GoogleFonts.inter(fontSize: 13, color: _Royal.text2)),
      ]));
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();
  @override
  Widget build(BuildContext context) => Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
            padding: const EdgeInsets.all(18),
            decoration: const BoxDecoration(gradient: _Royal.royal, shape: BoxShape.circle),
            child: const Icon(Icons.favorite, color: _Royal.gold, size: 32)),
        const SizedBox(height: 16),
        SizedBox(
            width: 160,
            child: LinearProgressIndicator(
                minHeight: 4,
                backgroundColor: _Royal.border,
                valueColor: const AlwaysStoppedAnimation(_Royal.blue))),
      ]));
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
      child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(color: _Royal.rose.withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(Icons.error_outline, color: _Royal.rose, size: 40)),
            const SizedBox(height: 16),
            Text('Impossible de charger le mariage',
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(message,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 12, color: _Royal.text2)),
            const SizedBox(height: 20),
            FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Réessayer'),
                style: FilledButton.styleFrom(backgroundColor: _Royal.blue)),
          ])));
}

String _fmtDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

String _fmtMoney(double v) {
  final neg = v < 0;
  final abs = v.abs();
  final whole = abs.floor();
  final cents = ((abs - whole) * 100).round();
  final s = whole.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  final centsStr = cents > 0 ? '.${cents.toString().padLeft(2, '0')}' : '';
  return '${neg ? '-' : ''}\$$buf$centsStr';
}
