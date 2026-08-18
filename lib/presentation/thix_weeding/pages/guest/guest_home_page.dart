// lib/presentation/thix_weeding/pages/guest/guest_home_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../core/failure.dart';
import '../../providers/wedding_provider.dart';
import '../../providers/countdown_provider.dart';

part 'guest_home_page.g.dart';

// ============================================================
// PALETTE — Charte THIX MARIAGE (Amour & Élégance / Lumineux)
// ============================================================
class _P {
  static const bg = Color(0xFFFFFBFC); // Blanc légèrement rosé, très lumineux
  static const surface = Colors.white;
  static const primary = Color(0xFFE31C4E); // Rouge passion / Rose profond
  static const primarySoft = Color(0xFFFFE3EA); // Rose pâle très clair
  static const secondary = Color(0xFFFF7A9C); // Rose vif complémentaire
  static const accent = Color(0xFFD4AF37); // Or premium / Champagne
  static const accentSoft = Color(0xFFFDF6E3);

  static const ink = Color(0xFF241521); // Texte principal, brun-noir chaleureux
  static const inkSoft = Color(0xFF8A7580); // Texte secondaire rosé-gris
  static const border = Color(0xFFF3E1E6); // Bordures très douces

  static const gradPrimary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE31C4E), Color(0xFFFF6B8B)],
  );

  // Ombre douce, lumineuse, "flottante"
  static final shadow = [
    BoxShadow(
      color: const Color(0xFFE31C4E).withOpacity(0.06),
      blurRadius: 16,
      offset: const Offset(0, 6),
    )
  ];
}

// ============================================================
// MODELE STATIQUE DES TUILES DU MENU INVITE
// ============================================================
enum _BadgeType { none, alert, count, live }

class _GuestMenuItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String route;
  final _BadgeType badgeType;
  final int? badgeCount;

  const _GuestMenuItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.route,
    this.badgeType = _BadgeType.none,
    this.badgeCount,
  });
}

const List<_GuestMenuItem> _kGuestMenu = [
  _GuestMenuItem(title: 'Invitation', subtitle: 'Voir les détails', icon: Icons.mail_outline_rounded, color: _P.primary, route: 'invitation'),
  _GuestMenuItem(title: 'Programme', subtitle: 'Déroulé de la journée', icon: Icons.event_note_outlined, color: _P.primary, route: 'programme'),
  _GuestMenuItem(title: 'Lieu & Accès', subtitle: 'Itinéraire & infos', icon: Icons.location_on_outlined, color: _P.primary, route: 'lieu'),
  _GuestMenuItem(title: 'RSVP', subtitle: 'Confirmer présence', icon: Icons.people_alt_outlined, color: _P.primary, route: 'rsvp', badgeType: _BadgeType.alert),
  _GuestMenuItem(title: 'Cadeaux', subtitle: 'Voir & contribuer', icon: Icons.card_giftcard_outlined, color: _P.primary, route: 'cadeaux'),
  _GuestMenuItem(title: 'Galerie', subtitle: 'Photos & vidéos', icon: Icons.photo_library_outlined, color: _P.primary, route: 'galerie'),
  _GuestMenuItem(title: 'Livre d\'or', subtitle: 'Laisser un message', icon: Icons.edit_outlined, color: _P.primary, route: 'livre-or'),
  _GuestMenuItem(title: 'Live', subtitle: 'Suivre en direct', icon: Icons.podcasts_outlined, color: _P.primary, route: 'live', badgeType: _BadgeType.live),
  _GuestMenuItem(title: 'Annonces', subtitle: 'Infos importantes', icon: Icons.campaign_outlined, color: _P.primary, route: 'annonces', badgeType: _BadgeType.count, badgeCount: 3),
  _GuestMenuItem(title: 'FAQ', subtitle: 'Vos questions', icon: Icons.help_outline_rounded, color: _P.primary, route: 'faq'),
  _GuestMenuItem(title: 'Remerciements', subtitle: 'Un mot pour vous', icon: Icons.volunteer_activism_outlined, color: _P.primary, route: 'remerciements'),
  _GuestMenuItem(title: 'Plus', subtitle: 'Autres options', icon: Icons.more_horiz_rounded, color: _P.primary, route: 'plus'),
];

// ============================================================
// PROVIDERS COMPLEMENTAIRES
// ============================================================
@riverpod
Future<Map<String, int>> guestEventStats(GuestEventStatsRef ref, String weddingId) async {
  await Future.delayed(const Duration(milliseconds: 200));
  return {'Invités confirmés': 84, 'En attente': 12, 'Cadeaux reçus': 19, 'Photos partagées': 56};
}

@riverpod
Future<List<Map<String, dynamic>>> guestVendors(GuestVendorsRef ref, String weddingId) async {
  await Future.delayed(const Duration(milliseconds: 250));
  return [
    {'name': 'Salle Émeraude', 'category': 'Lieu de réception', 'zone': 'Gombe', 'rating': 4.8, 'icon': Icons.villa_outlined},
    {'name': 'Chef Amani', 'category': 'Traiteur', 'zone': 'Limete', 'rating': 4.7, 'icon': Icons.restaurant_outlined},
    {'name': 'Studio Lumière', 'category': 'Photographe', 'zone': 'Kintambo', 'rating': 4.9, 'icon': Icons.camera_alt_outlined},
    {'name': 'Fleurs de Kin', 'category': 'Décoration', 'zone': 'Ngaliema', 'rating': 4.8, 'icon': Icons.local_florist_outlined},
  ];
}

@riverpod
Future<List<Map<String, dynamic>>> guestUpdates(GuestUpdatesRef ref, String weddingId) async {
  await Future.delayed(const Duration(milliseconds: 200));
  return [
    {'tag': 'PARKING', 'title': 'Parking disponible', 'subtitle': 'À partir de 15h', 'icon': Icons.local_parking_outlined},
    {'tag': 'DRESS CODE', 'title': 'Tenue élégante', 'subtitle': 'Couleurs pastel conseillées', 'icon': Icons.checkroom_outlined},
    {'tag': 'TRANSPORT', 'title': 'Navette gratuite', 'subtitle': 'Départ 15h30, Place Victoire', 'icon': Icons.directions_bus_outlined},
  ];
}

// ============================================================
// PAGE
// ============================================================
class GuestHomePage extends ConsumerStatefulWidget {
  final String weddingId;
  const GuestHomePage({super.key, required this.weddingId});

  @override
  ConsumerState<GuestHomePage> createState() => _GuestHomePageState();
}

class _GuestHomePageState extends ConsumerState<GuestHomePage> {
  Future<void> _onRefresh() async {
    ref.invalidate(guestWeddingProvider(widget.weddingId));
    await ref.read(guestWeddingProvider(widget.weddingId).future);
  }

  void _onTapGeneric(String label) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label bientôt disponible')));
  }

  @override
  Widget build(BuildContext context) {
    final weddingAsync = ref.watch(guestWeddingProvider(widget.weddingId));
    final statsAsync = ref.watch(guestEventStatsProvider(widget.weddingId));
    final vendorsAsync = ref.watch(guestVendorsProvider(widget.weddingId));
    final updatesAsync = ref.watch(guestUpdatesProvider(widget.weddingId));

    return Scaffold(
      backgroundColor: _P.bg,
      body: RefreshIndicator(
        color: _P.primary,
        onRefresh: _onRefresh,
        child: weddingAsync.when(
          data: (wedding) {
            final countdownState = ref.watch(countdownProvider(wedding.date)).value;

            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // HEADER — Bonjour Invité / menu / langue / avatar
                SliverToBoxAdapter(
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: _GuestHeader(),
                    ),
                  ),
                ),

                // HERO COUPLE
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _CoupleHero(
                      coupleNames: wedding.coupleNames,
                      welcomeMessage: wedding.welcomeMessage,
                      coverImageUrl: wedding.coverImageUrl,
                      countdownState: countdownState,
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 32)),

                // EN UN COUP D'OEIL
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: _SectionHeader(title: 'En un coup d\'œil'),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
                SliverToBoxAdapter(
                  child: statsAsync.when(
                    data: (stats) => _StatsRow(stats: stats),
                    loading: () => const SizedBox(height: 90),
                    error: (_, __) => const SizedBox(),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 32)),

                // GRILLE MENU — Style petits boutons ronds (4 colonnes)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: _SectionHeader(title: 'Toutes les rubriques'),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      mainAxisSpacing: 20,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.8, // Ratio adapté pour laisser de la place au texte en dessous
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final item = _kGuestMenu[index];
                        return _GuestMenuTile(
                          item: item,
                          onTap: () => context.push('/thix-weeding/guest/${widget.weddingId}/${item.route}'),
                        );
                      },
                      childCount: _kGuestMenu.length,
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 32)),

                // NOS PRESTATAIRES
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: _SectionHeader(title: 'Nos prestataires'),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
                SliverToBoxAdapter(
                  child: vendorsAsync.when(
                    data: (vendors) => _VendorsList(vendors: vendors, onTap: _onTapGeneric),
                    loading: () => const SizedBox(height: 220, child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: _P.primary))),
                    error: (_, __) => const SizedBox(),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 32)),

                // INFOS PRATIQUES
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: _SectionHeader(title: 'Infos pratiques'),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
                SliverToBoxAdapter(
                  child: updatesAsync.when(
                    data: (items) => _UpdatesList(items: items, onTap: _onTapGeneric),
                    loading: () => const SizedBox(height: 160, child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: _P.primary))),
                    error: (_, __) => const SizedBox(),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 32)),

                // BANDEAU ANNONCE PRINCIPALE
                if (wedding.hasAnnouncement) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _NewsBanner(text: wedding.announcement),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],

                // BANDEAU DE CONFIANCE
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: _TrustRow(),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            );
          },
          loading: () => const CustomScrollView(
            slivers: [SliverFillRemaining(child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: _P.primary)))],
          ),
          error: (e, _) => CustomScrollView(
            slivers: [SliverFillRemaining(child: Center(child: _ErrorView(error: e, weddingId: widget.weddingId)))],
          ),
        ),
      ),
      bottomNavigationBar: _GuestBottomNav(),
    );
  }
}

// ============================================================
// HEADER
// ============================================================
class _GuestHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _RoundIconButton(icon: Icons.menu_rounded, onTap: () {}),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Bonjour 👋', style: TextStyle(fontSize: 12, color: _P.inkSoft, fontWeight: FontWeight.w500)),
              Text('Invité(e)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _P.ink)),
            ],
          ),
        ),
        _RoundIconButton(
          onTap: () {},
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.language_rounded, size: 16, color: _P.primary),
              Text('FR', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: _P.primary)),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(shape: BoxShape.circle, color: _P.surface, boxShadow: _P.shadow),
              child: const Icon(Icons.person_rounded, color: _P.inkSoft, size: 22),
            ),
            Positioned(
              top: -2,
              right: -2,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(color: _P.accent, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData? icon;
  final Widget? child;
  final VoidCallback onTap;
  const _RoundIconButton({this.icon, this.child, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(color: _P.surface, shape: BoxShape.circle, boxShadow: _P.shadow),
        child: Center(child: child ?? Icon(icon, size: 20, color: _P.primary)),
      ),
    );
  }
}

// ============================================================
// HERO COUPLE + COUNTDOWN
// ============================================================
class _CoupleHero extends StatelessWidget {
  final String coupleNames;
  final String welcomeMessage;
  final String coverImageUrl;
  final CountdownState? countdownState;

  const _CoupleHero({
    required this.coupleNames,
    required this.welcomeMessage,
    required this.coverImageUrl,
    required this.countdownState,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Stack(
        children: [
          AspectRatio(
            aspectRatio: 0.95,
            child: Image.network(
              coverImageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(color: _P.primarySoft),
            ),
          ),
          // Dégradé rosé chaleureux plutôt que noir pur
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF3A0A18).withOpacity(0.35),
                    Colors.transparent,
                    const Color(0xFF3A0A18).withOpacity(0.55),
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
            ),
          ),
          Positioned(
            top: 24,
            left: 20,
            right: 90,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  coupleNames,
                  style: const TextStyle(fontFamily: 'Serif', fontSize: 32, color: Colors.white, fontWeight: FontWeight.w600, height: 1.1),
                ),
                const SizedBox(height: 8),
                Text(welcomeMessage, style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.35, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          Positioned(
            top: 20,
            right: 16,
            child: FilledButton.tonalIcon(
              onPressed: () {},
              style: FilledButton.styleFrom(
                backgroundColor: _P.surface.withOpacity(0.92),
                foregroundColor: _P.primary,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              icon: const Icon(Icons.ios_share_rounded, size: 16),
              label: const Text('Partager', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ),
          Positioned(left: 12, right: 12, bottom: 14, child: _CountdownCard(state: countdownState)),
        ],
      ),
    );
  }
}

class _CountdownCard extends StatelessWidget {
  final CountdownState? state;
  const _CountdownCard({this.state});

  @override
  Widget build(BuildContext context) {
    if (state == null) return const SizedBox(height: 84);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        color: _P.surface.withOpacity(0.96),
        borderRadius: BorderRadius.circular(22),
        boxShadow: _P.shadow,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(gradient: _P.gradPrimary, shape: BoxShape.circle),
            child: const Icon(Icons.calendar_month_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('JOUR J DANS', style: TextStyle(fontSize: 10, color: _P.inkSoft, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _CountItem(value: state!.days, label: 'Jours'),
                    _CountItem(value: state!.hours, label: 'Heures'),
                    _CountItem(value: state!.minutes, label: 'Min'),
                    _CountItem(value: state!.seconds, label: 'Sec'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CountItem extends StatelessWidget {
  final int value;
  final String label;
  const _CountItem({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text('$value', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: _P.primary)),
          Text(label, style: const TextStyle(fontSize: 9, color: _P.inkSoft, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ============================================================
// SECTION HEADER
// ============================================================
class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: _P.ink, letterSpacing: -0.3)),
        InkWell(
          onTap: () {},
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Text('Voir tout', style: TextStyle(fontSize: 12, color: _P.primary, fontWeight: FontWeight.w700)),
                Icon(Icons.chevron_right_rounded, size: 16, color: _P.primary),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// STATS ROW (Floating Cards)
// ============================================================
class _StatsRow extends StatelessWidget {
  final Map<String, int> stats;
  const _StatsRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    final entries = stats.entries.toList();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: List.generate(entries.length, (i) {
          final e = entries[i];
          return Expanded(
            child: Container(
              margin: EdgeInsets.only(right: i == entries.length - 1 ? 0 : 12),
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 6),
              decoration: BoxDecoration(color: _P.surface, borderRadius: BorderRadius.circular(18), boxShadow: _P.shadow),
              child: Column(
                children: [
                  Text('${e.value}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: _P.primary)),
                  const SizedBox(height: 4),
                  Text(e.key.toUpperCase(), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 8.5, color: _P.inkSoft, fontWeight: FontWeight.w600, height: 1.2, letterSpacing: 0.5)),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ============================================================
// TUILE DE MENU — Style Petits Boutons
// ============================================================
class _GuestMenuTile extends StatelessWidget {
  final _GuestMenuItem item;
  final VoidCallback onTap;
  const _GuestMenuTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: _P.primarySoft,
                  shape: BoxShape.circle,
                  boxShadow: _P.shadow, // Ombre douce pour le côté premium
                ),
                child: Icon(item.icon, color: _P.primary, size: 26),
              ),
              if (item.badgeType == _BadgeType.alert)
                Positioned(top: 0, right: 0, child: _DotBadge(child: const Text('!', style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w800)))),
              if (item.badgeType == _BadgeType.count)
                Positioned(top: 0, right: 0, child: _DotBadge(child: Text('${item.badgeCount}', style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w800)))),
              if (item.badgeType == _BadgeType.live)
                Positioned(
                  top: -4,
                  right: -12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(gradient: _P.gradPrimary, borderRadius: BorderRadius.circular(6)),
                    child: const Text('LIVE', style: TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            item.title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 10.5, color: _P.ink, height: 1.1),
          ),
        ],
      ),
    );
  }
}

class _DotBadge extends StatelessWidget {
  final Widget child;
  const _DotBadge({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      alignment: Alignment.center,
      decoration: const BoxDecoration(color: _P.primary, shape: BoxShape.circle),
      child: child,
    );
  }
}

// ============================================================
// NOS PRESTATAIRES
// ============================================================
class _VendorsList extends StatelessWidget {
  final List<Map<String, dynamic>> vendors;
  final void Function(String) onTap;
  const _VendorsList({required this.vendors, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: vendors.length,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (context, i) {
          final v = vendors[i];
          return InkWell(
            onTap: () => onTap(v['name'] as String),
            borderRadius: BorderRadius.circular(18),
            child: Container(
              width: 170,
              decoration: BoxDecoration(color: _P.surface, borderRadius: BorderRadius.circular(18), boxShadow: _P.shadow),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 110,
                    child: Stack(
                      children: [
                        Container(
                          width: double.infinity,
                          decoration: const BoxDecoration(
                            gradient: _P.gradPrimary,
                            borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
                          ),
                          child: Center(child: Icon(v['icon'] as IconData, size: 36, color: Colors.white38)),
                        ),
                        Positioned(
                          top: 12,
                          left: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: _P.surface, borderRadius: BorderRadius.circular(6)),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star_rounded, size: 12, color: _P.accent),
                                const SizedBox(width: 4),
                                Text('${v['rating']}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _P.ink)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(v['name'] as String, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _P.ink)),
                        const SizedBox(height: 2),
                        Text(v['category'] as String, style: const TextStyle(fontSize: 11, color: _P.primary, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.place_outlined, size: 12, color: _P.inkSoft),
                            const SizedBox(width: 4),
                            Expanded(child: Text(v['zone'] as String, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: _P.inkSoft))),
                          ],
                        ),
                      ],
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

// ============================================================
// INFOS PRATIQUES
// ============================================================
class _UpdatesList extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final void Function(String) onTap;
  const _UpdatesList({required this.items, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 160,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (context, i) {
          final a = items[i];
          return InkWell(
            onTap: () => onTap(a['title'] as String),
            borderRadius: BorderRadius.circular(18),
            child: Container(
              width: 150,
              decoration: BoxDecoration(color: _P.surface, borderRadius: BorderRadius.circular(18), boxShadow: _P.shadow),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 80,
                    child: Stack(
                      children: [
                        Container(
                          width: double.infinity,
                          decoration: const BoxDecoration(color: _P.accentSoft, borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
                          child: Center(child: Icon(a['icon'] as IconData, size: 28, color: _P.accent)),
                        ),
                        Positioned(
                          top: 12,
                          left: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(color: _P.ink, borderRadius: BorderRadius.circular(4)),
                            child: Text(a['tag'] as String, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.5)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(a['title'] as String, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _P.ink, height: 1.2)),
                        const Spacer(),
                        Text(a['subtitle'] as String, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: _P.primary, fontWeight: FontWeight.w800)),
                      ],
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

// ============================================================
// BANDEAU ANNONCE PRINCIPALE
// ============================================================
class _NewsBanner extends StatelessWidget {
  final String text;
  const _NewsBanner({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(gradient: _P.gradPrimary, borderRadius: BorderRadius.circular(18), boxShadow: _P.shadow),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), shape: BoxShape.circle),
            child: const Icon(Icons.campaign_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('INFORMATION', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700, fontSize: 10, letterSpacing: 0.8)),
                const SizedBox(height: 2),
                Text(text, style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// BANDEAU DE CONFIANCE
// ============================================================
class _TrustRow extends StatelessWidget {
  const _TrustRow();

  static const _items = [
    {'icon': Icons.favorite_border_rounded, 'label': 'Merci de\nvotre présence'},
    {'icon': Icons.lock_outline_rounded, 'label': 'Données\nprotégées'},
    {'icon': Icons.qr_code_rounded, 'label': 'Accès\nsécurisé'},
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(color: _P.surface, borderRadius: BorderRadius.circular(18), boxShadow: _P.shadow),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: _items.map((e) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(e['icon'] as IconData, size: 22, color: _P.primary),
              const SizedBox(height: 8),
              Text(e['label'] as String, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: _P.inkSoft, fontWeight: FontWeight.w500)),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ============================================================
// BOTTOM NAV
// ============================================================
class _GuestBottomNav extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _P.surface,
        boxShadow: [BoxShadow(color: const Color(0xFFE31C4E).withOpacity(0.08), blurRadius: 20, offset: const Offset(0, -4))],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 52,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              const _NavItem(icon: Icons.home_rounded, label: 'Accueil', selected: true),
              const _NavItem(icon: Icons.event_outlined, label: 'Agenda'),
              _HeartNavButton(onTap: () {}),
              const _NavItem(icon: Icons.chat_bubble_outline_rounded, label: 'Messages'),
              const _NavItem(icon: Icons.person_outline_rounded, label: 'Profil'),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  const _NavItem({required this.icon, required this.label, this.selected = false});

  @override
  Widget build(BuildContext context) {
    final color = selected ? _P.primary : _P.inkSoft;
    return InkWell(
      onTap: () {},
      borderRadius: BorderRadius.circular(8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 9, color: color, fontWeight: selected ? FontWeight.w700 : FontWeight.w400)),
        ],
      ),
    );
  }
}

class _HeartNavButton extends StatelessWidget {
  final VoidCallback onTap;
  const _HeartNavButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          gradient: _P.gradPrimary, // Rouge/rose pour rester dans la charte mariage
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: _P.primary.withOpacity(0.35), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 20),
      ),
    );
  }
}

// ============================================================
// ERREUR
// ============================================================
class _ErrorView extends ConsumerWidget {
  final Object error;
  final String weddingId;
  const _ErrorView({required this.error, required this.weddingId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.error_outline_rounded, size: 44, color: _P.inkSoft),
        const SizedBox(height: 12),
        Text(
          error is Failure ? (error as Failure).message : 'Erreur de chargement',
          textAlign: TextAlign.center,
          style: const TextStyle(color: _P.inkSoft),
        ),
        const SizedBox(height: 16),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: _P.primary),
          onPressed: () => ref.invalidate(guestWeddingProvider(weddingId)),
          child: const Text('Réessayer'),
        ),
      ],
    );
  }
}
