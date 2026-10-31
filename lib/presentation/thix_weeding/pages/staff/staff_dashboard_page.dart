// lib/presentation/thix_weeding/pages/staff/staff_dashboard_page.dart
// ============================================================================
// THIX WEDDING & EVENTS — STAFF DASHBOARD (PRODUCTION)
// Hero banner couple + Countdown live + 12 modules + Stats RSVP/Budget
// Branché sur les providers & routes EXISTANTS du dépôt (aucune modif requise)
// ============================================================================
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:thix_id/presentation/thix_weeding/pages/staff/models/thix_weeding_models.dart';
import 'package:thix_id/presentation/thix_weeding/pages/staff/providers/thix_weeding_providers.dart';

// ============================================================================
// DESIGN SYSTEM ROYAL
// ============================================================================
class _Royal {
  static const Color blue = Color(0xFF0B3B8F);
  static const Color purple = Color(0xFF6B46C1);
  static const Color gold = Color(0xFFD4AF37);
  static const Color goldDark = Color(0xFFB8860B);
  static const Color rose = Color(0xFFE31C4E);
  static const Color roseSoft = Color(0xFFFFE4EC);
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
// ROUTES (exactes — cf. thix_weeding_routes.dart)
// ============================================================================
class _R {
  static String base(String id) => '/thix-weeding/staff/$id';
  static String invites(String id) => '$base(id)/invites';
  static String invitation(String id) => '$base(id)/invitation';
  static String prestataires(String id) => '$base(id)/prestataires';
  static String planning(String id) => '$base(id)/planning';
  static String checklist(String id) => '$base(id)/checklist';
  static String budget(String id) => '$base(id)/budget';
  static String paiements(String id) => '$base(id)/paiements';
  static String galerie(String id) => '$base(id)/galerie';
  static String livreOr(String id) => '$base(id)/livre-or';
  static String messages(String id) => '$base(id)/messages';
  static String parametres(String id) => '$base(id)/parametres';
  static String myWeddings() => '/thix-weeding/staff/my-weddings';
}

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
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _anim.forward();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  void _refresh() {
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
          final summary = ref.watch(paymentsSummaryProvider(id)).valueOrNull;

          final unread = messages
              .where((m) => !m.isRead && m.senderType == 'guest')
              .length;

          return FadeTransition(
            opacity: _fade,
            child: RefreshIndicator(
              color: _Royal.blue,
              onRefresh: () async => _refresh(),
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // ── APP BAR ROYALE ────────────────────────────────────────
                  _RoyalAppBar(
                    wedding: wedding,
                    unread: unread,
                    onMessages: () => context.push(_R.messages(id)),
                    onSettings: () => context.push(_R.parametres(id)),
                  ),

                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        // ── HERO BANNER : PHOTO COUPLE + COUNTDOWN ──────────
                        _HeroBanner(wedding: wedding, coverUrl: gallery.isNotEmpty ? gallery.first.imageUrl : null),
                        const SizedBox(height: 16),

                        // ── STATS TEMPS RÉEL ────────────────────────────────
                        _StatsRow(guests: guests, vendors: vendors, tasks: tasks),
                        const SizedBox(height: 16),

                        // ── RSVP ────────────────────────────────────────────
                        _RsvpCard(guests: guests),
                        const SizedBox(height: 16),

                        // ── BUDGET ──────────────────────────────────────────
                        _BudgetCard(summary: summary),
                        const SizedBox(height: 24),

                        // ── MODULES (12 fonctionnalités) ────────────────────
                        _SectionTitle('Tous les modules', icon: Icons.apps),
                        const SizedBox(height: 12),
                        _ModulesGrid(
                          weddingId: id,
                          wedding: wedding,
                          guestsCount: guests.length,
                          vendorsBooked: vendors.where((v) => v.isBooked).length,
                          pendingTasks: tasks.where((t) => !t.isDone).length,
                          photosCount: gallery.length,
                          guestbookCount: guestbook.where((g) => g.isApproved).length,
                          unreadMessages: unread,
                        ),
                        const SizedBox(height: 24),

                        // ── CHECKLIST PROGRESSION ───────────────────────────
                        _SectionTitle('Checklist préparatifs', icon: Icons.checklist_outlined,
                            actionLabel: 'Voir tout', onAction: () => context.push(_R.checklist(id))),
                        const SizedBox(height: 12),
                        _ChecklistCard(tasks: tasks, weddingId: id),
                        const SizedBox(height: 24),

                        // ── GALERIE PREVIEW ─────────────────────────────────
                        _SectionTitle('Galerie souvenirs', icon: Icons.photo_library_outlined,
                            actionLabel: 'Gérer', onAction: () => context.push(_R.galerie(id))),
                        const SizedBox(height: 12),
                        _GalleryStrip(gallery: gallery, weddingId: id),
                        const SizedBox(height: 24),

                        // ── PRESTATAIRES ────────────────────────────────────
                        _SectionTitle('Prestataires', icon: Icons.storefront_outlined,
                            actionLabel: 'Voir tout', onAction: () => context.push(_R.prestataires(id))),
                        const SizedBox(height: 12),
                        _VendorsCard(vendors: vendors),
                        const SizedBox(height: 24),

                        // ── PAIEMENTS RÉCENTS ───────────────────────────────
                        _SectionTitle('Paiements récents', icon: Icons.payments_outlined,
                            actionLabel: 'Voir tout', onAction: () => context.push(_R.paiements(id))),
                        const SizedBox(height: 12),
                        _PaymentsCard(payments: payments),
                        const SizedBox(height: 24),

                        // ── LIVRE D'OR ──────────────────────────────────────
                        _SectionTitle("Livre d'or", icon: Icons.menu_book_outlined,
                            actionLabel: 'Modérer', onAction: () => context.push(_R.livreOr(id))),
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

// ============================================================================
// APP BAR
// ============================================================================
class _RoyalAppBar extends StatelessWidget {
  final WeddingModel wedding;
  final int unread;
  final VoidCallback onMessages;
  final VoidCallback onSettings;

  const _RoyalAppBar({
    required this.wedding,
    required this.unread,
    required this.onMessages,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      floating: true,
      snap: true,
      backgroundColor: Colors.white,
      elevation: 0,
      foregroundColor: _Royal.text,
      title: Text(
        'Dashboard',
        style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: _Royal.blue),
      ),
      actions: [
        // Statut publication invitation
        Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: wedding.invitationPublished
                ? _Royal.green.withOpacity(0.1)
                : _Royal.amber.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                wedding.invitationPublished ? Icons.verified : Icons.hourglass_bottom,
                size: 12,
                color: wedding.invitationPublished ? _Royal.green : _Royal.amber,
              ),
              const SizedBox(width: 4),
              Text(
                wedding.invitationPublished ? 'Publiée' : 'Brouillon',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: wedding.invitationPublished ? _Royal.green : _Royal.amber,
                ),
              ),
            ],
          ),
        ),
        Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline),
              onPressed: onMessages,
            ),
            if (unread > 0)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: _Royal.rose,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Text(
                    '$unread',
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          onPressed: onSettings,
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}

// ============================================================================
// HERO BANNER — PHOTO COUPLE + COUNTDOWN LIVE
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
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Photo du couple (1ère photo galerie) ou monogramme royal
          if (coverUrl != null && coverUrl!.isNotEmpty)
            Image.network(
              coverUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const _MonogramFallback(),
              loadingBuilder: (_, child, progress) =>
                  progress == null ? child : const _MonogramFallback(),
            )
          else
            const _MonogramFallback(),

          // Dégradé de lisibilité
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.15),
                  Colors.black.withOpacity(0.55),
                  const Color(0xFF061F47).withOpacity(0.92),
                ],
                stops: const [0.0, 0.55, 1.0],
              ),
            ),
          ),

          // Contenu
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Badge code unique mariage
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _Royal.gold.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _Royal.gold.withOpacity(0.6)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.qr_code_2, size: 12, color: _Royal.gold),
                          const SizedBox(width: 6),
                          Text(
                            wedding.uniqueCode,
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: _Royal.gold,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    if (date != null) _JBadge(date: date),
                  ],
                ),
                const SizedBox(height: 12),

                // Noms du couple
                Text(
                  wedding.coupleNames.isEmpty ? 'Notre Mariage' : wedding.coupleNames,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.place_outlined, size: 14, color: Colors.white70),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        [
                          if (wedding.venue != null && wedding.venue!.isNotEmpty) wedding.venue!,
                          if (date != null) _fmtDate(date),
                        ].join('  •  '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(fontSize: 12, color: Colors.white70),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Countdown live
                if (date != null) _LiveCountdown(target: date),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

/// Badge J-X / JOUR J / CÉLÉBRÉ
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
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white),
      ),
    );
  }
}

/// Countdown temps réel (1s) — Jours / Heures / Min / Sec
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
        decoration: BoxDecoration(
          gradient: _Royal.greenG,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '🎉 Mariage célébré — revivez les souvenirs',
          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
        ),
      );
    }

    final d = _left.inDays;
    final h = _left.inHours % 24;
    final m = _left.inMinutes % 60;
    final s = _left.inSeconds % 60;

    return Row(
      children: [
        _TimeCell(value: d, label: 'JOURS'),
        _TimeSep(),
        _TimeCell(value: h, label: 'HEURES'),
        _TimeSep(),
        _TimeCell(value: m, label: 'MIN'),
        _TimeSep(),
        _TimeCell(value: s, label: 'SEC'),
      ],
    );
  }
}

class _TimeCell extends StatelessWidget {
  final int value;
  final String label;
  const _TimeCell({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.25)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value.toString().padLeft(2, '0'),
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 8,
              fontWeight: FontWeight.w700,
              color: Colors.white70,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeSep extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Text(
          ':',
          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white54),
        ),
      );
}

/// Fallback royal si pas de photo : monogramme des mariés
class _MonogramFallback extends ConsumerWidget {
  const _MonogramFallback();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: const BoxDecoration(gradient: _Royal.royal),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _Royal.gold.withOpacity(0.7), width: 2),
              ),
              child: const Icon(Icons.favorite, color: _Royal.gold, size: 40),
            ),
            const SizedBox(height: 10),
            Text(
              'THIX WEDDING',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Colors.white54,
                letterSpacing: 3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// STATS TEMPS RÉEL
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

    return Row(
      children: [
        Expanded(child: _StatCard(label: 'Invités', value: '$totalSeats', icon: Icons.people, gradient: _Royal.royal)),
        const SizedBox(width: 10),
        Expanded(child: _StatCard(label: 'Présents', value: '$present', icon: Icons.check_circle, gradient: _Royal.greenG)),
        const SizedBox(width: 10),
        Expanded(child: _StatCard(label: 'Prestat.', value: '${vendors.length}', icon: Icons.storefront, gradient: _Royal.goldG)),
        const SizedBox(width: 10),
        Expanded(child: _StatCard(label: 'Tâches', value: '$done/${tasks.length}', icon: Icons.task_alt, gradient: _Royal.roseG)),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final LinearGradient gradient;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: _Royal.cardBox(radius: 14),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(gradient: gradient, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: Colors.white, size: 16),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: _Royal.text),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(fontSize: 10, color: _Royal.text2),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// CARTE RSVP
// ============================================================================
class _RsvpCard extends StatelessWidget {
  final List<GuestModel> guests;
  const _RsvpCard({required this.guests});

  @override
  Widget build(BuildContext context) {
    final confirmed = guests.where((g) => g.rsvpStatus == 'confirmed').length;
    final declined = guests.where((g) => g.rsvpStatus == 'declined').length;
    final pending = guests.length - confirmed - declined;
    final total = guests.isEmpty ? 1 : guests.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _Royal.cardBox(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.mark_email_read_outlined, size: 18, color: _Royal.blue),
              const SizedBox(width: 8),
              Text('Confirmations RSVP', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              minHeight: 10,
              value: confirmed / total,
              backgroundColor: _Royal.rose.withOpacity(0.15),
              valueColor: const AlwaysStoppedAnimation(_Royal.green),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _RsvpChip(label: 'Confirmés', count: confirmed, color: _Royal.green),
              const SizedBox(width: 8),
              _RsvpChip(label: 'En attente', count: pending, color: _Royal.amber),
              const SizedBox(width: 8),
              _RsvpChip(label: 'Déclinés', count: declined, color: _Royal.rose),
            ],
          ),
        ],
      ),
    );
  }
}

class _RsvpChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _RsvpChip({required this.label, required this.count, required this.color});

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
            Text(
              '$count',
              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: color),
            ),
            Text(label, style: GoogleFonts.inter(fontSize: 10, color: color.withOpacity(0.9))),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// CARTE BUDGET
// ============================================================================
class _BudgetCard extends StatelessWidget {
  final Map<String, double>? summary;
  const _BudgetCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final budget = summary?['budget'] ?? 0.0;
    final spent = summary?['spent'] ?? 0.0;
    final paid = summary?['paid'] ?? 0.0;
    final remaining = summary?['remaining'] ?? (budget - spent);
    final ratio = budget > 0 ? (spent / budget).clamp(0.0, 1.0) : 0.0;
    final over = spent > budget && budget > 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _Royal.cardBox(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_wallet_outlined, size: 18, color: _Royal.blue),
              const SizedBox(width: 8),
              Text('Budget', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  gradient: over ? _Royal.roseG : _Royal.goldG,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${(ratio * 100).toStringAsFixed(0)}%',
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              minHeight: 10,
              value: ratio.toDouble(),
              backgroundColor: _Royal.border,
              valueColor: AlwaysStoppedAnimation(over ? _Royal.rose : _Royal.green),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _MoneyCell(label: 'Dépensé', value: spent, color: _Royal.rose),
              _MoneyCell(label: 'Payé', value: paid, color: _Royal.blue),
              _MoneyCell(label: 'Restant', value: remaining, color: over ? _Royal.rose : _Royal.green),
            ],
          ),
        ],
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
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 10, color: _Royal.text2)),
          const SizedBox(height: 2),
          Text(
            _fmtMoney(value),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: color),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// GRILLE DES 12 MODULES
// ============================================================================
class _ModulesGrid extends StatelessWidget {
  final String weddingId;
  final WeddingModel wedding;
  final int guestsCount;
  final int vendorsBooked;
  final int pendingTasks;
  final int photosCount;
  final int guestbookCount;
  final int unreadMessages;

  const _ModulesGrid({
    required this.weddingId,
    required this.wedding,
    required this.guestsCount,
    required this.vendorsBooked,
    required this.pendingTasks,
    required this.photosCount,
    required this.guestbookCount,
    required this.unreadMessages,
  });

  @override
  Widget build(BuildContext context) {
    final id = weddingId;
    final modules = <_Module>[
      _Module('Invités', '$guestsCount', Icons.people_outline, _Royal.royal, _R.invites(id)),
      _Module('Invitation', wedding.invitationPublished ? 'Publiée' : 'Brouillon', Icons.mail_outline, _Royal.roseG, _R.invitation(id)),
      _Module('Prestataires', '$vendorsBooked réservés', Icons.storefront_outlined, _Royal.goldG, _R.prestataires(id)),
      _Module('Planning', 'Jour J', Icons.schedule_outlined, _Royal.royal, _R.planning(id)),
      _Module('Checklist', '$pendingTasks restantes', Icons.checklist_outlined, _Royal.greenG, _R.checklist(id), badge: pendingTasks),
      _Module('Budget', 'Suivi', Icons.account_balance_wallet_outlined, _Royal.goldG, _R.budget(id)),
      _Module('Paiements', 'Transactions', Icons.payments_outlined, _Royal.greenG, _R.paiements(id)),
      _Module('Galerie', '$photosCount photos', Icons.photo_library_outlined, _Royal.roseG, _R.galerie(id)),
      _Module("Livre d'or", '$guestbookCount msgs', Icons.menu_book_outlined, _Royal.goldG, _R.livreOr(id)),
      _Module('Messages', unreadMessages > 0 ? '$unreadMessages nouveaux' : 'À jour', Icons.chat_bubble_outline, _Royal.royal, _R.messages(id), badge: unreadMessages),
      _Module('Paramètres', 'Réglages', Icons.settings_outlined, LinearGradient(colors: [Colors.grey.shade600, Colors.grey.shade800]), _R.parametres(id)),
      _Module('Mes mariages', 'Multi-événements', Icons.favorite_border, _Royal.roseG, _R.myWeddings()),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.92,
      ),
      itemCount: modules.length,
      itemBuilder: (_, i) => _ModuleTile(module: modules[i]),
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

  _Module(this.title, this.subtitle, this.icon, this.gradient, this.route, {this.badge = 0});
}

class _ModuleTile extends StatelessWidget {
  final _Module module;
  const _ModuleTile({required this.module});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => context.push(module.route),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: _Royal.cardBox(radius: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      gradient: module.gradient,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(module.icon, color: Colors.white, size: 18),
                  ),
                  if (module.badge > 0)
                    Positioned(
                      right: -5,
                      top: -5,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: _Royal.rose,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Text(
                          '${module.badge}',
                          style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                      ),
                    ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    module.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: _Royal.text),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    module.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(fontSize: 9, color: _Royal.text2),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// CHECKLIST
// ============================================================================
class _ChecklistCard extends StatelessWidget {
  final List<ChecklistModel> tasks;
  final String weddingId;
  const _ChecklistCard({required this.tasks, required this.weddingId});

  @override
  Widget build(BuildContext context) {
    final done = tasks.where((t) => t.isDone).length;
    final ratio = tasks.isEmpty ? 0.0 : done / tasks.length;

    final upcoming = [...tasks]
      ..removeWhere((t) => t.isDone)
      ..sort((a, b) {
        final da = a.dueDate;
        final db = b.dueDate;
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return da.compareTo(db);
      });

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _Royal.cardBox(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 44,
                height: 44,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 44,
                      height: 44,
                      child: CircularProgressIndicator(
                        value: ratio,
                        strokeWidth: 5,
                        backgroundColor: _Royal.border,
                        valueColor: const AlwaysStoppedAnimation(_Royal.green),
                      ),
                    ),
                    Text(
                      '${(ratio * 100).toStringAsFixed(0)}%',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: _Royal.text),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$done / ${tasks.length} tâches accomplies',
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    Text(
                      upcoming.isEmpty ? 'Tout est prêt 🎉' : 'Prochaine : ${upcoming.first.title}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(fontSize: 12, color: _Royal.text2),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (upcoming.isNotEmpty) ...[
            const SizedBox(height: 14),
            ...upcoming.take(3).map((t) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: t.dueDate != null && t.dueDate!.isBefore(DateTime.now())
                              ? _Royal.rose
                              : _Royal.amber,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          t.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (t.dueDate != null)
                        Text(
                          '${t.dueDate!.day.toString().padLeft(2, '0')}/${t.dueDate!.month.toString().padLeft(2, '0')}',
                          style: GoogleFonts.inter(fontSize: 11, color: _Royal.text2),
                        ),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }
}

// ============================================================================
// GALERIE PREVIEW
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
        child: Column(
          children: [
            Icon(Icons.photo_camera_outlined, size: 36, color: _Royal.text2),
            const SizedBox(height: 8),
            Text(
              'Aucune photo pour le moment',
              style: GoogleFonts.inter(fontSize: 13, color: _Royal.text2),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => context.push(_R.galerie(weddingId)),
              icon: const Icon(Icons.add_a_photo_outlined, size: 16),
              label: const Text('Ajouter des photos'),
              style: FilledButton.styleFrom(backgroundColor: _Royal.blue),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: 130,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: gallery.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final g = gallery[i];
          return ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.network(
              g.imageUrl,
              width: 130,
              height: 130,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 130,
                height: 130,
                color: _Royal.border,
                child: const Icon(Icons.broken_image_outlined, color: _Royal.text2),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ============================================================================
// PRESTATAIRES
// ============================================================================
class _VendorsCard extends StatelessWidget {
  final List<VendorModel> vendors;
  const _VendorsCard({required this.vendors});

  @override
  Widget build(BuildContext context) {
    if (vendors.isEmpty) {
      return _EmptyCard(message: 'Aucun prestataire engagé', icon: Icons.storefront_outlined);
    }

    final booked = vendors.where((v) => v.isBooked).toList();
    final shown = (booked + vendors.where((v) => !v.isBooked).toList()).take(3);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _Royal.cardBox(),
      child: Column(
        children: shown
            .map((v) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          gradient: v.isBooked ? _Royal.greenG : _Royal.goldG,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          v.isBooked ? Icons.verified : Icons.hourglass_bottom,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              v.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
                            ),
                            Text(
                              v.category,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(fontSize: 11, color: _Royal.text2),
                            ),
                          ],
                        ),
                      ),
                      if (v.price != null)
                        Text(
                          _fmtMoney(v.price!),
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: _Royal.blue),
                        ),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }
}

// ============================================================================
// PAIEMENTS RÉCENTS
// ============================================================================
class _PaymentsCard extends StatelessWidget {
  final List<PaymentModel> payments;
  const _PaymentsCard({required this.payments});

  @override
  Widget build(BuildContext context) {
    if (payments.isEmpty) {
      return _EmptyCard(message: 'Aucun paiement enregistré', icon: Icons.payments_outlined);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _Royal.cardBox(),
      child: Column(
        children: payments.take(3).map((p) {
          final ok = p.status == 'completed';
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: (ok ? _Royal.green : _Royal.amber).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    ok ? Icons.check_circle_outline : Icons.schedule,
                    color: ok ? _Royal.green : _Royal.amber,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.vendorName ?? p.expenseTitle ?? 'Paiement',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '${p.method} • ${p.createdAt.day.toString().padLeft(2, '0')}/${p.createdAt.month.toString().padLeft(2, '0')}',
                        style: GoogleFonts.inter(fontSize: 11, color: _Royal.text2),
                      ),
                    ],
                  ),
                ),
                Text(
                  _fmtMoney(p.amount),
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: ok ? _Royal.green : _Royal.amber,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ============================================================================
// LIVRE D'OR
// ============================================================================
class _GuestbookCard extends StatelessWidget {
  final List<GuestbookModel> entries;
  const _GuestbookCard({required this.entries});

  @override
  Widget build(BuildContext context) {
    final approved = entries.where((e) => e.isApproved).toList();
    if (approved.isEmpty) {
      return _EmptyCard(message: 'Aucun message approuvé', icon: Icons.menu_book_outlined);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _Royal.cardBox(),
      child: Column(
        children: approved.take(2).map((e) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    gradient: _Royal.roseG,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.format_quote, color: Colors.white, size: 16),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e.message,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(fontSize: 13, fontStyle: FontStyle.italic),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '— ${e.guestName}',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _Royal.rose,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ============================================================================
// WIDGETS UTILITAIRES
// ============================================================================
class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _SectionTitle(this.title, {required this.icon, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: _Royal.blue),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: _Royal.text),
          ),
        ),
        if (actionLabel != null)
          GestureDetector(
            onTap: onAction,
            child: Text(
              actionLabel!,
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: _Royal.blue),
            ),
          ),
      ],
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final String message;
  final IconData icon;
  const _EmptyCard({required this.message, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _Royal.cardBox(),
      child: Column(
        children: [
          Icon(icon, size: 32, color: _Royal.text2),
          const SizedBox(height: 8),
          Text(message, style: GoogleFonts.inter(fontSize: 13, color: _Royal.text2)),
        ],
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: const BoxDecoration(gradient: _Royal.royal, shape: BoxShape.circle),
            child: const Icon(Icons.favorite, color: _Royal.gold, size: 32),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: 160,
            child: LinearProgressIndicator(
              minHeight: 4,
              backgroundColor: _Royal.border,
              valueColor: const AlwaysStoppedAnimation(_Royal.blue),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: _Royal.rose.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline, color: _Royal.rose, size: 40),
            ),
            const SizedBox(height: 16),
            Text(
              'Impossible de charger le mariage',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 12, color: _Royal.text2),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Réessayer'),
              style: FilledButton.styleFrom(backgroundColor: _Royal.blue),
            ),
          ],
        ),
      ),
    );
  }
}

/// Formatage milliers sans dépendance intl : 1250000 → "1 250 000"
String _fmtMoney(double v) {
  final neg = v < 0;
  final s = v.round().abs().toString();
  final buf = StringBuffer();
  var c = 0;
  for (var i = s.length - 1; i >= 0; i--) {
    buf.write(s[i]);
    c++;
    if (c % 3 == 0 && i > 0) buf.write(' ');
  }
  return (neg ? '-' : '') + buf.toString().split('').reversed.join();
}
