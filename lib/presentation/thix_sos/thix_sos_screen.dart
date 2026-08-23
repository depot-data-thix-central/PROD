/// THIX SOS — Homepage production (Design System Intégré)
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart'; // ✅ Import de ton Design System

import 'models/sos_models.dart';
import 'pages/sos_actif_page.dart';
import 'pages/mes_secours_page.dart';
import 'pages/mes_incidents_page.dart';
import 'pages/chambre_crise_page.dart';
import 'pages/ajouter_secours_page.dart';
import 'providers/sos_providers.dart';
import 'widgets/sos_button.dart';
import 'widgets/nearby_alerts_card.dart';

// ============================================================================
// COMPOSANT RÉUTILISABLE : BOÎTE EN VERRE (GLASSMORPHISM)
// ============================================================================
class GlassBox extends StatelessWidget {
  final Widget child;
  final double blur;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Border? border;

  const GlassBox({
    super.key,
    required this.child,
    this.blur = 15.0,
    this.borderRadius = ThixPolicy.rLg,
    this.padding = ThixPolicy.cardPadding,
    this.color,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: color ?? Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(borderRadius),
            border: border ?? Border.all(color: Colors.white.withOpacity(0.15), width: 1),
          ),
          child: child,
        ),
      ),
    );
  }
}

class ThixSosScreen extends ConsumerWidget {
  const ThixSosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contactsAsync = ref.watch(sosContactsProvider);
    final activeAsync = ref.watch(activeSosProvider);
    final triggerState = ref.watch(triggerSosProvider);
    final isTriggering = triggerState.isLoading;

    ref.listen(activeSosProvider, (prev, next) {
      next.whenData((incident) {
        if (incident != null && incident.isActive && context.mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => SosActifPage(incidentId: incident.id),
            ),
          );
        }
      });
    });

    return Scaffold(
      backgroundColor: ThixPolicy.inkDeep, // 🌟 Fond Premium Sombre
      body: Stack(
        children: [
          // ─── BACKGROUND GLOW (Effet d'urgence rouge) ───
          Positioned(
            top: -50, right: -100,
            child: Container(
              width: 300, height: 300, 
              decoration: BoxDecoration(
                shape: BoxShape.circle, 
                color: ThixPolicy.danger.withOpacity(0.15),
                boxShadow: [BoxShadow(color: ThixPolicy.danger.withOpacity(0.2), blurRadius: 120, spreadRadius: 100)]
              )
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                const _HeaderOfficiel(),
                Expanded(
                  child: RefreshIndicator(
                    color: ThixPolicy.danger,
                    backgroundColor: ThixPolicy.inkDeep,
                    onRefresh: () async {
                      ref.invalidate(sosContactsProvider);
                      ref.invalidate(activeSosProvider);
                      ref.invalidate(sosHistoryProvider);
                    },
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                      padding: const EdgeInsets.fromLTRB(
                        ThixPolicy.s16,
                        ThixPolicy.s24,
                        ThixPolicy.s16,
                        140, // 🌟 Espace pour la Bottom Nav flottante
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // --- BOUTON SOS CENTRAL ---
                          SosButton(
                            enabled: !isTriggering,
                            isLoading: isTriggering,
                            onTriggered: () async {
                              final incident = await ref
                                  .read(triggerSosProvider.notifier)
                                  .trigger();
                              if (incident != null && context.mounted) {
                                ref
                                    .read(sosHeartbeatControllerProvider.notifier)
                                    .start(incident.id);
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        SosActifPage(incidentId: incident.id),
                                  ),
                                );
                              } else if (context.mounted) {
                                final err = ref.read(triggerSosProvider).error;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      err?.toString() ?? 'Échec du déclenchement SOS',
                                      style: ThixPolicy.bodyStyle.copyWith(color: Colors.white),
                                    ),
                                    backgroundColor: ThixPolicy.danger,
                                  ),
                                );
                              }
                            },
                          ),
                          const SizedBox(height: ThixPolicy.s12),
                          Text(
                            'Appuyer et maintenir 2 secondes',
                            textAlign: TextAlign.center,
                            style: ThixPolicy.labelStyle.copyWith(
                              color: Colors.white54,
                              fontWeight: ThixPolicy.medium,
                            ),
                          ),
                          const SizedBox(height: ThixPolicy.s40),

                          // --- MES SECOURS ---
                          _SectionLabel('MES SECOURS', actionText: 'Gérer', onAction: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const MesSecoursPage()));
                          }),
                          const SizedBox(height: ThixPolicy.s12),
                          contactsAsync.when(
                            data: (contacts) {
                              return _UnifiedSecoursCard(
                                contacts: contacts,
                                onCircleTap: (circle) => _handleCircleTap(context, ref, circle),
                              );
                            },
                            loading: () => const Center(child: CircularProgressIndicator(color: ThixPolicy.danger)),
                            error: (e, _) => Text('Erreur secours', style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.danger)),
                          ),
                          const SizedBox(height: ThixPolicy.s32),

                          // --- ALERTES À PROXIMITÉ ---
                          const NearbyAlertsCard(), 
                          const SizedBox(height: ThixPolicy.s32),

                          // --- ACTIONS RAPIDES ---
                          const _SectionLabel('ACTIONS RAPIDES'),
                          const SizedBox(height: ThixPolicy.s12),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            child: Row(
                              children: [
                                _QuickActionChip(icon: Icons.location_on_rounded, label: 'Partager', onTap: () => _soon(context, 'Partager')),
                                const SizedBox(width: ThixPolicy.s12),
                                _QuickActionChip(icon: Icons.timer_rounded, label: 'Safe Check', onTap: () => _soon(context, 'Safe Check')),
                                const SizedBox(width: ThixPolicy.s12),
                                _QuickActionChip(icon: Icons.route_rounded, label: 'Mes trajets', onTap: () => _soon(context, 'Trajets')),
                                const SizedBox(width: ThixPolicy.s12),
                                _QuickActionChip(icon: Icons.campaign_rounded, label: 'Signaler', onTap: () => _soon(context, 'Signaler')),
                              ],
                            ),
                          ),
                          const SizedBox(height: ThixPolicy.s32),

                          // --- MODULES ---
                          _NavCardProminent(
                            icon: Icons.shield_rounded,
                            title: 'CHAMBRE DE CRISE',
                            subtitle: 'Gérer vos incidents actifs en temps réel',
                            onTap: () {
                              final incident = activeAsync.valueOrNull;
                              if (incident != null && incident.isActive) {
                                Navigator.push(context, MaterialPageRoute(builder: (_) => ChambreCrisePage(incidentId: incident.id)));
                              } else {
                                Navigator.push(context, MaterialPageRoute(builder: (_) => const MesIncidentsPage()));
                              }
                            },
                          ),
                          const SizedBox(height: ThixPolicy.s12),
                          Row(
                            children: [
                              Expanded(
                                child: _NavCardCompact(
                                  icon: Icons.search_rounded,
                                  title: 'THIX RECHERCHE',
                                  subtitle: 'Avis & disparitions',
                                  onTap: () => _soon(context, 'Thix Recherche'),
                                ),
                              ),
                              const SizedBox(width: ThixPolicy.s12),
                              Expanded(
                                child: _NavCardCompact(
                                  icon: Icons.folder_special_rounded,
                                  title: 'MES INCIDENTS',
                                  subtitle: 'Historique & rapports',
                                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MesIncidentsPage())),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 🌟 BOTTOM NAV FLOTTANTE
          const Positioned(bottom: 24, left: 16, right: 16, child: _BottomNavGlass(currentIndex: 2)),
        ],
      ),
    );
  }

  void _handleCircleTap(BuildContext context, WidgetRef ref, int circle) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AjouterSecoursPage(initialCircle: circle)),
    ).then((ok) {
      if (ok == true) ref.invalidate(sosContactsProvider);
    });
  }

  static void _soon(BuildContext context, String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label — bientôt disponible', style: ThixPolicy.bodyStyle.copyWith(color: Colors.white, fontWeight: ThixPolicy.bold)),
        backgroundColor: ThixPolicy.inkDeep,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rSm)),
      ),
    );
  }
}

// ───────────────────────── Header Officiel ─────────────────────────
class _HeaderOfficiel extends StatelessWidget {
  const _HeaderOfficiel();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16, vertical: ThixPolicy.s12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Icon(Icons.menu_rounded, color: Colors.white, size: 28),
          Column(
            children: [
              Text(
                'X THIX',
                style: ThixPolicy.h1Style.copyWith(
                  fontWeight: ThixPolicy.bold,
                  letterSpacing: 1.2,
                  color: Colors.white,
                ),
              ),
              Text(
                'CONNECTER • PROTÉGER • AGIR',
                style: ThixPolicy.microStyle.copyWith(
                  fontWeight: ThixPolicy.bold,
                  letterSpacing: 1.5,
                  color: ThixPolicy.danger, // Touche d'accent rouge
                ),
              ),
            ],
          ),
          Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 28),
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(color: ThixPolicy.danger, shape: BoxShape.circle, border: Border.all(color: ThixPolicy.inkDeep, width: 1.5)),
                      child: Text('3', style: ThixPolicy.microStyle.copyWith(color: Colors.white, fontWeight: ThixPolicy.bold, fontSize: 8)),
                    ),
                  )
                ],
              ),
              const SizedBox(width: ThixPolicy.s16),
              Container(
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white.withOpacity(0.3), width: 2)),
                child: const CircleAvatar(
                  radius: 16,
                  backgroundColor: ThixPolicy.primaryDeep,
                  backgroundImage: NetworkImage('https://i.pravatar.cc/150?img=11'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Section Label ─────────────────────────
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, {this.actionText, this.onAction});
  final String text;
  final String? actionText;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          text,
          style: ThixPolicy.labelStyle.copyWith(
            fontWeight: ThixPolicy.bold,
            letterSpacing: 1.2,
            color: Colors.white70,
          ),
        ),
        if (actionText != null)
          GestureDetector(
            onTap: onAction,
            child: Text(
              actionText!,
              style: ThixPolicy.labelStyle.copyWith(color: Colors.white, fontWeight: ThixPolicy.bold),
            ),
          ),
      ],
    );
  }
}

// ───────────────────────── Carte "Mes Secours" (Glassmorphism) ─────────────────────────
class _UnifiedSecoursCard extends StatelessWidget {
  final List<dynamic> contacts; 
  final Function(int) onCircleTap;

  const _UnifiedSecoursCard({
    required this.contacts,
    required this.onCircleTap,
  });

  @override
  Widget build(BuildContext context) {
    return GlassBox(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _buildRow(context, 1, 'Cercle 1 – Prioritaire'),
          const Divider(height: 1, indent: 64, color: Colors.white12),
          _buildRow(context, 2, 'Cercle 2 – Secondaire'),
          const Divider(height: 1, indent: 64, color: Colors.white12),
          _buildRow(context, 3, 'Cercle 3 – Urgence'),
        ],
      ),
    );
  }

  Widget _buildRow(BuildContext context, int level, String title) {
    final circleContacts = contacts.where((c) => c.circle == level).toList();
    final count = circleContacts.length;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onCircleTap(level),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16, vertical: ThixPolicy.s16),
          child: Row(
            children: [
              // Badge de niveau
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: level == 1 ? ThixPolicy.danger : Colors.white.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    level.toString(),
                    style: ThixPolicy.titleStyle.copyWith(
                      color: Colors.white, 
                      fontWeight: ThixPolicy.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: ThixPolicy.s16),
              // Textes
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: ThixPolicy.bodyStyle.copyWith(fontWeight: ThixPolicy.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      count == 0 ? 'Aucun secours' : '$count secours',
                      style: ThixPolicy.captionStyle.copyWith(
                        color: count == 0 ? ThixPolicy.danger : Colors.white54,
                      ),
                    ),
                  ],
                ),
              ),
              // Miniatures photos (Avatars)
              if (count > 0) _buildAvatars(context, circleContacts),
              if (count > 0) const SizedBox(width: ThixPolicy.s12),
              const Icon(Icons.chevron_right_rounded, color: Colors.white30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatars(BuildContext context, List<dynamic> circleContacts) {
    final displayContacts = circleContacts.take(3).toList();
    const double avatarSize = 28.0;
    const double overlap = 14.0; 
    
    return SizedBox(
      width: avatarSize + (displayContacts.length - 1) * overlap,
      height: avatarSize,
      child: Stack(
        children: List.generate(displayContacts.length, (index) {
          final contact = displayContacts[index];
          
          String? imageUrl;
          try { imageUrl = contact.avatarUrl ?? contact.photoUrl; } catch (_) {}
          
          return Positioned(
            right: index * overlap,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: ThixPolicy.inkDeep, width: 2.5), 
              ),
              child: CircleAvatar(
                radius: (avatarSize / 2) - 2.5,
                backgroundColor: ThixPolicy.border,
                backgroundImage: imageUrl != null ? NetworkImage(imageUrl) : null,
                child: imageUrl == null ? const Icon(Icons.person, size: 14, color: Colors.white) : null,
              ),
            ),
          );
        }).reversed.toList(),
      ),
    );
  }
}

// ───────────────────────── Action Rapide (Glassmorphism) ─────────────────────────
class _QuickActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionChip({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: GlassBox(
        borderRadius: ThixPolicy.rFull,
        padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s20, vertical: ThixPolicy.s12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: ThixPolicy.s8),
            Text(label, style: ThixPolicy.labelStyle.copyWith(color: Colors.white, fontWeight: ThixPolicy.semiBold)),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── Module Pleine Largeur (Glass Rouge) ─────────────────────────
class _NavCardProminent extends StatelessWidget {
  const _NavCardProminent({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: GlassBox(
        color: ThixPolicy.danger.withOpacity(0.15),
        border: Border.all(color: ThixPolicy.danger.withOpacity(0.3), width: 1),
        padding: ThixPolicy.cardPaddingLarge,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: ThixPolicy.danger.withOpacity(0.2), shape: BoxShape.circle),
              child: Icon(icon, color: ThixPolicy.danger, size: 28),
            ),
            const SizedBox(width: ThixPolicy.s16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: ThixPolicy.titleStyle.copyWith(color: Colors.white, fontWeight: ThixPolicy.bold)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: ThixPolicy.bodySmallStyle.copyWith(color: Colors.white70)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white54, size: 16),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── Nav Card Compact (Glass) ─────────────────────────
class _NavCardCompact extends StatelessWidget {
  const _NavCardCompact({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: GlassBox(
        padding: ThixPolicy.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(height: ThixPolicy.s16),
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: ThixPolicy.labelStyle.copyWith(color: Colors.white, fontWeight: ThixPolicy.bold)),
            const SizedBox(height: 4),
            Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: ThixPolicy.captionStyle.copyWith(color: Colors.white54)),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── Bottom Nav Flottante (Glass) ─────────────────────────
class _BottomNavGlass extends StatelessWidget {
  const _BottomNavGlass({required this.currentIndex});
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    return GlassBox(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      borderRadius: 30,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(context, Icons.home_rounded, 'Accueil', 0),
          _navItem(context, Icons.chat_bubble_rounded, 'Chat', 1),
          // Bouton central "SOS" Accent
          GestureDetector(
            onTap: () {},
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              decoration: BoxDecoration(color: ThixPolicy.danger, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: ThixPolicy.danger.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))]),
              child: Row(
                children: [
                  const Icon(Icons.sos_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 6),
                  Text('SOS', style: ThixPolicy.labelStyle.copyWith(fontWeight: ThixPolicy.bold, color: Colors.white)),
                ],
              ),
            ),
          ),
          _navItem(context, Icons.map_rounded, 'Carte', 3),
          _navItem(context, Icons.person_rounded, 'Profil', 4),
        ],
      ),
    );
  }

  Widget _navItem(BuildContext context, IconData icon, String label, int idx) {
    final sel = currentIndex == idx;
    return GestureDetector(
      onTap: () {
        if (idx == 0) Navigator.of(context).popUntil((r) => r.isFirst);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: sel ? Colors.white : Colors.white54, size: 24),
          const SizedBox(height: 4),
          Text(label, style: ThixPolicy.microStyle.copyWith(fontWeight: sel ? ThixPolicy.bold : ThixPolicy.semiBold, color: sel ? Colors.white : Colors.white54, fontSize: 9)),
        ],
      ),
    );
  }
}
