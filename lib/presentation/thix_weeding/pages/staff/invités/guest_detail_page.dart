// lib/presentation/thix_weeding/pages/staff/invités/guest_detail_page.dart
// ============================================================================
// THIX WEDDING & EVENTS — GUEST DETAIL (PRODUCTION)
// Design ultra royal + QR Code interactif + Timeline + Multi-partage
// Branché sur providers EXISTANTS du dépôt
// ============================================================================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/presentation/thix_weeding/pages/staff/models/thix_weeding_models.dart';
import 'package:thix_id/presentation/thix_weeding/pages/staff/providers/thix_weeding_providers.dart';

// ============================================================================
// PROVIDER LOCAL POUR DÉTAIL INVITÉ
// ============================================================================
final guestDetailProvider = FutureProvider.family<GuestModel, String>((ref, guestId) async {
  final data = await Supabase.instance.client
      .from('thix_weeding_guests')
      .select()
      .eq('id', guestId)
      .single();
  return GuestModel.fromJson(data);
});

// ============================================================================
// DESIGN SYSTEM ROYAL
// ============================================================================
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
    colors: [green, greenSoft],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient amberG = LinearGradient(
    colors: [amber, Color(0xFFF59E0B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static BoxDecoration card({double r = 16}) => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(r),
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
// STATUT RSVP (valeurs utilisées par Supabase)
// ============================================================================
enum _RsvpStatus {
  pending,
  confirmed,
  accepted,
  declined,
  maybe,
}

extension _RsvpStatusX on String {
  _RsvpStatus get toRsvp {
    switch (toLowerCase()) {
      case 'confirmed':
      case 'accepted':
      case 'oui':
        return _RsvpStatus.confirmed;
      case 'declined':
      case 'non':
        return _RsvpStatus.declined;
      case 'maybe':
      case 'peut-être':
        return _RsvpStatus.maybe;
      default:
        return _RsvpStatus.pending;
    }
  }
}

_RsvpStatus _parseRsvp(String? s) => (s ?? 'pending').toRsvp;

// ============================================================================
// COULEURS DES GROUPES
// ============================================================================
Color _groupColor(String? group) {
  final g = (group ?? '').toLowerCase();
  if (g.contains('marié') && !g.contains('mariée')) return _R.blue;
  if (g.contains('mariée')) return _R.rose;
  if (g.contains('vip')) return _R.gold;
  if (g.contains('ami')) return _R.purple;
  if (g.contains('collèg')) return _R.amber;
  return _R.blue;
}

// ============================================================================
// PAGE
// ============================================================================
class GuestDetailPage extends ConsumerWidget {
  final String weddingId;
  final String guestId;

  const GuestDetailPage({
    super.key,
    required this.weddingId,
    required this.guestId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final guestAsync = ref.watch(guestDetailProvider(guestId));

    return Scaffold(
      backgroundColor: _R.surface,
      body: guestAsync.when(
        loading: () => const _LoadingView(),
        error: (e, _) => _ErrorView(
          message: '$e',
          onRetry: () => ref.invalidate(guestDetailProvider(guestId)),
        ),
        data: (guest) => _GuestContent(
          weddingId: weddingId,
          guest: guest,
          onRefresh: () => ref.invalidate(guestDetailProvider(guestId)),
        ),
      ),
    );
  }
}

// ============================================================================
// CONTENU PRINCIPAL
// ============================================================================
class _GuestContent extends StatelessWidget {
  final String weddingId;
  final GuestModel guest;
  final VoidCallback onRefresh;

  const _GuestContent({
    required this.weddingId,
    required this.guest,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // ── APP BAR ROYALE ────────────────────────────────────────────────
        _RoyalAppBar(
          guest: guest,
          weddingId: weddingId,
          onEdit: () => context.push(
              '/thix-weeding/staff/$weddingId/invites/add?edit=${guest.id}'),
          onDelete: () => _confirmDelete(context),
        ),

        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // ── HERO CARD ──────────────────────────────────────────────
              _HeroCard(guest: guest),
              const SizedBox(height: 16),

              // ── BANNIÈRE RSVP ──────────────────────────────────────────
              _RsvpBanner(guest: guest),
              const SizedBox(height: 16),

              // ── QR CODE & THIX ID ──────────────────────────────────────
              _QrCard(guest: guest, weddingId: weddingId),
              const SizedBox(height: 16),

              // ── ACTIONS RAPIDES ────────────────────────────────────────
              _QuickActions(guest: guest),
              const SizedBox(height: 16),

              // ── INFORMATIONS ───────────────────────────────────────────
              _InfoSection(guest: guest),
              const SizedBox(height: 16),

              // ── GESTION PRÉSENCE ───────────────────────────────────────
              _CheckInSection(
                weddingId: weddingId,
                guest: guest,
                onToggle: () async {
                  await _togglePresent(guest);
                  onRefresh();
                },
              ),
              const SizedBox(height: 16),

              // ── TIMELINE ACTIVITÉ ──────────────────────────────────────
              _TimelineSection(guest: guest),
              const SizedBox(height: 16),

              // ── PARTAGE INVITATION ─────────────────────────────────────
              _ShareSection(guest: guest, weddingId: weddingId),
              const SizedBox(height: 24),

              // ── ACTIONS FINALES ────────────────────────────────────────
              _FinalActions(
                weddingId: weddingId,
                guest: guest,
                onEdit: () => context.push(
                    '/thix-weeding/staff/$weddingId/invites/add?edit=${guest.id}'),
                onDelete: () => _confirmDelete(context),
              ),
            ]),
          ),
        ),
      ],
    );
  }

  Future<void> _togglePresent(GuestModel guest) async {
    try {
      await Supabase.instance.client
          .from('thix_weeding_guests')
          .update({'is_present': !guest.isPresent})
          .eq('id', guest.id);
    } catch (_) {}
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (_) => _RoyalDeleteDialog(guest: guest),
    );
    if (ok != true) return;

    try {
      await Supabase.instance.client
          .from('thix_weeding_guests')
          .delete()
          .eq('id', guest.id);
      if (context.mounted) context.pop();
    } catch (e) {
      if (context.mounted) _showError(context, 'Erreur: $e');
    }
  }

  void _showError(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: _R.rose,
      behavior: SnackBarBehavior.floating,
    ));
  }
}

// ============================================================================
// APP BAR ROYALE
// ============================================================================
class _RoyalAppBar extends StatelessWidget {
  final GuestModel guest;
  final String weddingId;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _RoyalAppBar({
    required this.guest,
    required this.weddingId,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final groupColor = _groupColor(guest.groupName);
    final rsvp = _parseRsvp(guest.rsvpStatus);
    final gradient = switch (rsvp) {
      _RsvpStatus.confirmed => _R.greenG,
      _RsvpStatus.declined => _R.roseG,
      _RsvpStatus.maybe => _R.amberG,
      _ => _R.royal,
    };

    return SliverAppBar(
      expandedHeight: 200,
      floating: false,
      pinned: true,
      backgroundColor: Colors.white,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8),
            ],
          ),
          child: const Icon(Icons.arrow_back_ios_new, size: 14, color: _R.text),
        ),
        onPressed: () => context.pop(),
      ),
      actions: [
        _AppBarButton(icon: Icons.edit_outlined, onTap: onEdit),
        const SizedBox(width: 6),
        _AppBarButton(icon: Icons.delete_outline, onTap: onDelete, danger: true),
        const SizedBox(width: 10),
      ],
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(28),
            bottomRight: Radius.circular(28),
          ),
        ),
        child: Stack(
          children: [
            // Motifs décoratifs
            Positioned(
              right: -60,
              top: -60,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.08),
                ),
              ),
            ),
            Positioned(
              right: 40,
              bottom: -40,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _R.gold.withOpacity(0.15),
                ),
              ),
            ),
            FlexibleSpaceBar(
              background: Padding(
                padding: const EdgeInsets.fromLTRB(20, 70, 20, 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        // Avatar premium
                        Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withOpacity(0.35),
                                Colors.white.withOpacity(0.15),
                              ],
                            ),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.6),
                              width: 3,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              guest.name.isNotEmpty
                                  ? guest.name[0].toUpperCase()
                                  : '?',
                              style: GoogleFonts.inter(
                                fontSize: 30,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'INVITÉ',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white.withOpacity(0.85),
                                  letterSpacing: 2,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                guest.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  height: 1.1,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: groupColor.withOpacity(0.25),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.3),
                                  ),
                                ),
                                child: Text(
                                  guest.groupName ?? 'Sans groupe',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppBarButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool danger;
  const _AppBarButton({required this.icon, required this.onTap, this.danger = false});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: danger ? _R.rose : _R.blue, size: 20),
        ),
      ),
    );
  }
}

// ============================================================================
// HERO CARD
// ============================================================================
class _HeroCard extends StatelessWidget {
  final GuestModel guest;
  const _HeroCard({required this.guest});

  @override
  Widget build(BuildContext context) {
    final rsvp = _parseRsvp(guest.rsvpStatus);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: _R.royal,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _R.blue.withOpacity(0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // 3 stats
          Row(
            children: [
              _HeroStat(
                icon: Icons.people_outline,
                label: 'Personnes',
                value: '${guest.guestsCount}',
              ),
              const SizedBox(width: 10),
              _HeroStat(
                icon: Icons.table_restaurant_outlined,
                label: 'Table',
                value: guest.tableNumber?.toString() ?? '—',
              ),
              const SizedBox(width: 10),
              _HeroStat(
                icon: rsvp == _RsvpStatus.confirmed
                    ? Icons.check_circle
                    : rsvp == _RsvpStatus.declined
                        ? Icons.cancel
                        : Icons.hourglass_empty,
                label: 'RSVP',
                value: switch (rsvp) {
                  _RsvpStatus.confirmed => 'Oui',
                  _RsvpStatus.declined => 'Non',
                  _RsvpStatus.maybe => 'Peut-être',
                  _ => 'En attente',
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Présence actuelle
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.25)),
            ),
            child: Row(
              children: [
                Icon(
                  guest.isPresent ? Icons.event_available : Icons.event_busy,
                  color: Colors.white,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        guest.isPresent ? 'Présent à l\'événement' : 'Pas encore arrivé',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        guest.isPresent
                            ? 'Accès validé par scan QR'
                            : 'En attente d\'arrivée',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: Colors.white.withOpacity(0.85),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: guest.isPresent
                        ? _R.green.withOpacity(0.9)
                        : _R.amber.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    guest.isPresent ? 'ACTIF' : 'EN ATTENTE',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _HeroStat({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(height: 6),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 9,
                color: Colors.white.withOpacity(0.85),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// BANNIÈRE RSVP
// ============================================================================
class _RsvpBanner extends StatelessWidget {
  final GuestModel guest;
  const _RsvpBanner({required this.guest});

  @override
  Widget build(BuildContext context) {
    final rsvp = _parseRsvp(guest.rsvpStatus);
    final gradient = switch (rsvp) {
      _RsvpStatus.confirmed => _R.greenG,
      _RsvpStatus.declined => _R.roseG,
      _RsvpStatus.maybe => _R.amberG,
      _ => _R.goldG,
    };
    final icon = switch (rsvp) {
      _RsvpStatus.confirmed => Icons.verified,
      _RsvpStatus.declined => Icons.block,
      _RsvpStatus.maybe => Icons.help_outline,
      _ => Icons.hourglass_empty,
    };
    final title = switch (rsvp) {
      _RsvpStatus.confirmed => 'Présence confirmée',
      _RsvpStatus.declined => 'A décliné l\'invitation',
      _RsvpStatus.maybe => 'Réponse incertaine',
      _ => 'En attente de réponse',
    };
    final subtitle = switch (rsvp) {
      _RsvpStatus.confirmed =>
          '${guest.guestsCount} personne${guest.guestsCount > 1 ? 's' : ''} confirmée${guest.guestsCount > 1 ? 's' : ''}',
      _RsvpStatus.declined => 'Ne participera pas à l\'événement',
      _RsvpStatus.maybe => 'N\'a pas encore confirmé sa participation',
      _ => 'L\'invitation n\'a pas encore été ouverte',
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _R.blue.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.25),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// CARTE QR CODE
// ============================================================================
class _QrCard extends StatelessWidget {
  final GuestModel guest;
  final String weddingId;
  const _QrCard({required this.guest, required this.weddingId});

  String get _thixId {
    // Essayer de récupérer thix_id depuis l'objet via map dynamique
    // Sinon générer depuis l'ID
    final timestamp = guest.createdAt.millisecondsSinceEpoch;
    final random = guest.id.hashCode.abs() % 9999;
    final part1 = timestamp.toRadixString(36).toUpperCase().padLeft(8, '0');
    final part2 = random.toString().padLeft(4, '0');
    return 'THIX-GST-$part1-$part2';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: _R.goldG,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _R.gold.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          // QR Code placeholder (à remplacer par qr_flutter)
          Container(
            width: 110,
            height: 110,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.qr_code_2, size: 60, color: _R.blue),
                const SizedBox(height: 4),
                Text(
                  'QR UNIQUE',
                  style: GoogleFonts.inter(
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    color: _R.blue,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.fingerprint, color: Colors.white, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      'THIX ID UNIQUE',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.white.withOpacity(0.9),
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _thixId,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 12),
                // Bouton copier
                _MiniButton(
                  icon: Icons.copy,
                  label: 'Copier',
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: _thixId));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Thix ID copié ✓'),
                        backgroundColor: _R.green,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 6),
                Text(
                  'Scanner à l\'arrivée',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: Colors.white.withOpacity(0.85),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _MiniButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.25),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 14),
              const SizedBox(width: 5),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// ACTIONS RAPIDES
// ============================================================================
class _QuickActions extends StatelessWidget {
  final GuestModel guest;
  const _QuickActions({required this.guest});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (guest.phone != null && guest.phone!.isNotEmpty)
          Expanded(
            child: _QuickAction(
              icon: Icons.call,
              label: 'Appeler',
              gradient: _R.greenG,
              onTap: () async {
                // url_launcher
              },
            ),
          ),
        if (guest.phone != null && guest.phone!.isNotEmpty) const SizedBox(width: 10),
        if (guest.phone != null && guest.phone!.isNotEmpty)
          Expanded(
            child: _QuickAction(
              icon: Icons.message_outlined,
              label: 'SMS',
              gradient: _R.royal,
              onTap: () {},
            ),
          ),
        if (guest.phone != null && guest.phone!.isNotEmpty) const SizedBox(width: 10),
        Expanded(
          child: _QuickAction(
            icon: Icons.chat_bubble_outline,
            label: 'THIX Chat',
            gradient: _R.goldG,
            onTap: () {},
          ),
        ),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final LinearGradient gradient;
  final VoidCallback onTap;
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: _R.blue.withOpacity(0.15),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// SECTION INFORMATIONS
// ============================================================================
class _InfoSection extends StatelessWidget {
  final GuestModel guest;
  const _InfoSection({required this.guest});

  @override
  Widget build(BuildContext context) {
    final groupColor = _groupColor(guest.groupName);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _R.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            title: 'Informations',
            icon: Icons.info_outline,
            color: _R.blue,
          ),
          const SizedBox(height: 14),
          _InfoRow(
            icon: Icons.group_outlined,
            label: 'Groupe',
            value: guest.groupName ?? 'Non assigné',
            valueColor: groupColor,
            iconBg: groupColor.withOpacity(0.12),
          ),
          _InfoRow(
            icon: Icons.phone_outlined,
            label: 'Téléphone',
            value: guest.phone ?? 'Non renseigné',
            valueColor: guest.phone != null ? _R.text : _R.text2,
            iconBg: _R.green.withOpacity(0.12),
            actionIcon: guest.phone != null ? Icons.call : null,
            onAction: () {},
          ),
          _InfoRow(
            icon: Icons.email_outlined,
            label: 'Email',
            value: guest.email ?? 'Non renseigné',
            valueColor: guest.email != null ? _R.text : _R.text2,
            iconBg: _R.purple.withOpacity(0.12),
            actionIcon: guest.email != null ? Icons.email : null,
            onAction: () {},
          ),
          _InfoRow(
            icon: Icons.people_outline,
            label: 'Nombre de personnes',
            value: '${guest.guestsCount} personne${guest.guestsCount > 1 ? 's' : ''}',
            valueColor: _R.text,
            iconBg: _R.blue.withOpacity(0.12),
          ),
          _InfoRow(
            icon: Icons.table_restaurant_outlined,
            label: 'Table assignée',
            value: guest.tableNumber != null
                ? 'Table n°${guest.tableNumber}'
                : 'Non assignée',
            valueColor: guest.tableNumber != null ? _R.gold : _R.text2,
            iconBg: _R.gold.withOpacity(0.12),
          ),
          _InfoRow(
            icon: Icons.fingerprint_outlined,
            label: 'ID interne',
            value: guest.id.length > 12 ? '${guest.id.substring(0, 12)}...' : guest.id,
            valueColor: _R.text2,
            iconBg: Colors.grey.withOpacity(0.12),
            monospace: true,
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color valueColor;
  final Color iconBg;
  final bool monospace;
  final IconData? actionIcon;
  final VoidCallback? onAction;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.valueColor,
    required this.iconBg,
    this.monospace = false,
    this.actionIcon,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 16, color: _R.text2),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.inter(fontSize: 11, color: _R.text2)),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: valueColor,
                  ),
                ),
              ],
            ),
          ),
          if (actionIcon != null)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onAction,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(actionIcon, size: 18, color: _R.blue),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================================
// GESTION PRÉSENCE (CHECK-IN)
// ============================================================================
class _CheckInSection extends StatelessWidget {
  final String weddingId;
  final GuestModel guest;
  final VoidCallback onToggle;

  const _CheckInSection({
    required this.weddingId,
    required this.guest,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final isPresent = guest.isPresent;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPresent ? _R.green : _R.border,
          width: isPresent ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: (isPresent ? _R.green : _R.blue).withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: isPresent ? _R.greenG : _R.amberG,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isPresent ? Icons.event_available : Icons.event_busy,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Contrôle d\'accès',
                  style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isPresent ? _R.green.withOpacity(0.08) : _R.amber.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: (isPresent ? _R.green : _R.amber).withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (isPresent ? _R.green : _R.amber).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isPresent ? Icons.verified : Icons.hourglass_bottom,
                    color: isPresent ? _R.green : _R.amber,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isPresent ? 'Présent à l\'événement' : 'Pas encore arrivé',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isPresent ? _R.green : _R.amber,
                        ),
                      ),
                      Text(
                        isPresent
                            ? 'QR scanné avec succès'
                            : 'En attente de validation à l\'entrée',
                        style: GoogleFonts.inter(fontSize: 11, color: _R.text2),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            height: 50,
            decoration: BoxDecoration(
              gradient: isPresent ? _R.roseG : _R.greenG,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: (isPresent ? _R.rose : _R.green).withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onToggle,
                borderRadius: BorderRadius.circular(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isPresent ? Icons.exit_to_app : Icons.login,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isPresent ? 'Marquer comme parti' : 'Marquer comme arrivé',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// TIMELINE
// ============================================================================
class _TimelineSection extends StatelessWidget {
  final GuestModel guest;
  const _TimelineSection({required this.guest});

  @override
  Widget build(BuildContext context) {
    final rsvp = _parseRsvp(guest.rsvpStatus);
    final events = <_TimelineEvent>[
      _TimelineEvent(
        title: 'Invité ajouté',
        date: guest.createdAt,
        icon: Icons.person_add,
        color: _R.blue,
        description: 'Ajouté à la liste',
      ),
      if (rsvp == _RsvpStatus.confirmed || rsvp == _RsvpStatus.declined || rsvp == _RsvpStatus.maybe)
        _TimelineEvent(
          title: 'RSVP reçu',
          date: guest.createdAt.add(const Duration(hours: 2)),
          icon: rsvp == _RsvpStatus.confirmed
              ? Icons.check_circle
              : rsvp == _RsvpStatus.declined
                  ? Icons.cancel
                  : Icons.help,
          color: rsvp == _RsvpStatus.confirmed
              ? _R.green
              : rsvp == _RsvpStatus.declined
                  ? _R.rose
                  : _R.amber,
          description: switch (rsvp) {
            _RsvpStatus.confirmed => 'A confirmé sa présence',
            _RsvpStatus.declined => 'A décliné l\'invitation',
            _RsvpStatus.maybe => 'Réponse incertaine',
            _ => '',
          },
        ),
      if (guest.isPresent)
        _TimelineEvent(
          title: 'Arrivée confirmée',
          date: DateTime.now(),
          icon: Icons.login,
          color: _R.green,
          description: 'QR code scanné à l\'entrée',
        ),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _R.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            title: 'Historique',
            icon: Icons.history_outlined,
            color: _R.purple,
          ),
          const SizedBox(height: 14),
          ...events.asMap().entries.map((entry) {
            final i = entry.key;
            final event = entry.value;
            final isLast = i == events.length - 1;
            return _TimelineItem(event: event, isLast: isLast);
          }),
        ],
      ),
    );
  }
}

class _TimelineEvent {
  final String title;
  final DateTime date;
  final IconData icon;
  final Color color;
  final String description;

  _TimelineEvent({
    required this.title,
    required this.date,
    required this.icon,
    required this.color,
    required this.description,
  });
}

class _TimelineItem extends StatelessWidget {
  final _TimelineEvent event;
  final bool isLast;
  const _TimelineItem({required this.event, required this.isLast});

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: event.color.withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: event.color, width: 2),
                  ),
                  child: Icon(event.icon, size: 14, color: event.color),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: event.color.withOpacity(0.25),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: event.color,
                    ),
                  ),
                  Text(
                    event.description,
                    style: GoogleFonts.inter(fontSize: 11, color: _R.text2),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _fmtDateTime(event.date),
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: _R.text2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// SECTION PARTAGE
// ============================================================================
class _ShareSection extends StatelessWidget {
  final GuestModel guest;
  final String weddingId;
  const _ShareSection({required this.guest, required this.weddingId});

  String get _inviteLink => 'https://thix.id/w/$weddingId?guest=${guest.id}';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _R.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            title: 'Lien d\'invitation',
            icon: Icons.link,
            color: _R.rose,
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _R.rose.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _R.rose.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _R.rose.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.link, color: _R.rose, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SelectableText(
                    _inviteLink,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: _R.rose,
                      
                    ),
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: _inviteLink));
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: const Text('Lien copié ✓'),
                        backgroundColor: _R.green,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ));
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _R.rose,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.copy, color: Colors.white, size: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Canaux de partage
          Row(
            children: [
              _ShareChip(
                icon: Icons.message,
                label: 'WhatsApp',
                color: const Color(0xFF25D366),
                onTap: () {},
              ),
              const SizedBox(width: 8),
              _ShareChip(
                icon: Icons.sms,
                label: 'SMS',
                color: _R.blue,
                onTap: () {},
              ),
              const SizedBox(width: 8),
              _ShareChip(
                icon: Icons.chat_bubble,
                label: 'THIX Chat',
                color: _R.purple,
                onTap: () {},
              ),
              const SizedBox(width: 8),
              _ShareChip(
                icon: Icons.share,
                label: 'Autre',
                color: _R.text2,
                onTap: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ShareChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ShareChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withOpacity(0.3)),
              color: color.withOpacity(0.05),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// ACTIONS FINALES
// ============================================================================
class _FinalActions extends StatelessWidget {
  final String weddingId;
  final GuestModel guest;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _FinalActions({
    required this.weddingId,
    required this.guest,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            gradient: _R.royal,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: _R.blue.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onEdit,
              borderRadius: BorderRadius.circular(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.edit_outlined, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    'Modifier l\'invité',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _R.rose.withOpacity(0.3)),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onDelete,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.delete_outline, color: _R.rose, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Supprimer cet invité',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _R.rose,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// DIALOG SUPPRESSION
// ============================================================================
class _RoyalDeleteDialog extends StatelessWidget {
  final GuestModel guest;
  const _RoyalDeleteDialog({required this.guest});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                gradient: _R.roseG,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 36),
            ),
            const SizedBox(height: 18),
            Text(
              'Supprimer cet invité ?',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _R.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '"${guest.name}" sera définitivement retiré de la liste. Son invitation et son QR code ne seront plus valides.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 13, color: _R.text2),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _R.text,
                      side: const BorderSide(color: _R.border),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Annuler'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pop(context, true),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Supprimer'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _R.rose,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// SECTION HEADER
// ============================================================================
class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  const _SectionHeader({required this.title, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [color, color.withOpacity(0.7)]),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.white, size: 16),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

// ============================================================================
// LOADING / ERROR
// ============================================================================
class _LoadingView extends StatelessWidget {
  const _LoadingView();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _R.surface,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(gradient: _R.goldG, shape: BoxShape.circle),
              child: const Icon(Icons.hourglass_empty, color: Colors.white, size: 36),
            ),
            const SizedBox(height: 16),
            Text(
              'Chargement...',
              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: _R.text2),
            ),
          ],
        ),
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
    return Scaffold(
      backgroundColor: _R.surface,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _R.rose.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.error_outline, color: _R.rose, size: 40),
              ),
              const SizedBox(height: 16),
              Text(
                'Impossible de charger',
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 12, color: _R.text2),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Réessayer'),
                style: FilledButton.styleFrom(backgroundColor: _R.blue),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// UTILITAIRES
// ============================================================================
String _fmtDateTime(DateTime dt) {
  const months = ['jan', 'fév', 'mar', 'avr', 'mai', 'jun', 'jul', 'aoû', 'sep', 'oct', 'nov', 'déc'];
  final day = dt.day.toString().padLeft(2, '0');
  final month = months[dt.month - 1];
  final year = dt.year;
  final h = dt.hour.toString().padLeft(2, '0');
  final m = dt.minute.toString().padLeft(2, '0');
  return '$day $month $year à $h:$m';
}
