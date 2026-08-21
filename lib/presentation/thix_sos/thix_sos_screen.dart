/// THIX SOS — Homepage production (Design System Intégré)
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

    // Utilisation des couleurs du thème courant (Clair ou Sombre)
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            const _HeaderOfficiel(),
            Expanded(
              child: RefreshIndicator(
                color: ThixPolicy.danger,
                backgroundColor: ThixPolicy.card,
                onRefresh: () async {
                  ref.invalidate(sosContactsProvider);
                  ref.invalidate(activeSosProvider);
                  ref.invalidate(sosHistoryProvider);
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                    ThixPolicy.s16,
                    ThixPolicy.s24,
                    ThixPolicy.s16,
                    ThixPolicy.s28,
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
                                  style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.onBrand),
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
                          color: ThixPolicy.textSecondary,
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
                      _SectionLabel('ACTIONS RAPIDES'),
                      const SizedBox(height: ThixPolicy.s12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: [
                            _QuickActionChip(icon: Icons.location_on, label: 'Partager', onTap: () => _soon(context, 'Partager')),
                            const SizedBox(width: ThixPolicy.s8),
                            _QuickActionChip(icon: Icons.timer, label: 'Safe Check', onTap: () => _soon(context, 'Safe Check')),
                            const SizedBox(width: ThixPolicy.s8),
                            _QuickActionChip(icon: Icons.route, label: 'Mes trajets', onTap: () => _soon(context, 'Trajets')),
                            const SizedBox(width: ThixPolicy.s8),
                            _QuickActionChip(icon: Icons.campaign, label: 'Signaler', onTap: () => _soon(context, 'Signaler')),
                          ],
                        ),
                      ),
                      const SizedBox(height: ThixPolicy.s32),

                      // --- MODULES ---
                      _NavCardProminent(
                        icon: Icons.shield,
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
                              icon: Icons.folder_special,
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
      bottomNavigationBar: const _BottomNav(currentIndex: 2),
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
        content: Text('$label — bientôt disponible', style: ThixPolicy.bodyStyle.copyWith(color: ThixPolicy.onBrand)),
        backgroundColor: ThixPolicy.primaryDeep,
        behavior: SnackBarBehavior.floating,
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
          Icon(Icons.menu, color: Theme.of(context).colorScheme.onSurface, size: 28),
          Column(
            children: [
              Text(
                'X THIX',
                style: ThixPolicy.h1Style.copyWith(
                  fontWeight: ThixPolicy.bold, // ou w900
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                'CONNECTER • PROTÉGER • AGIR',
                style: ThixPolicy.microStyle.copyWith(
                  fontWeight: ThixPolicy.bold,
                  letterSpacing: 1.5,
                  color: ThixPolicy.textSecondary,
                ),
              ),
            ],
          ),
          Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(Icons.notifications_none_rounded, color: Theme.of(context).colorScheme.onSurface, size: 28),
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: ThixPolicy.danger, shape: BoxShape.circle),
                      child: Text('3', style: ThixPolicy.microStyle.copyWith(color: ThixPolicy.onBrand, fontWeight: ThixPolicy.bold)),
                    ),
                  )
                ],
              ),
              const SizedBox(width: ThixPolicy.s16),
              const CircleAvatar(
                radius: 16,
                backgroundColor: ThixPolicy.border,
                backgroundImage: NetworkImage('https://i.pravatar.cc/150?img=11'),
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
            color: ThixPolicy.textSecondary,
          ),
        ),
        if (actionText != null)
          GestureDetector(
            onTap: onAction,
            child: Text(
              actionText!,
              style: ThixPolicy.labelStyle.copyWith(color: ThixPolicy.primary),
            ),
          ),
      ],
    );
  }
}

// ───────────────────────── Carte "Mes Secours" Unifiée ─────────────────────────
class _UnifiedSecoursCard extends StatelessWidget {
  final List<dynamic> contacts; 
  final Function(int) onCircleTap;

  const _UnifiedSecoursCard({
    required this.contacts,
    required this.onCircleTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor, 
        borderRadius: BorderRadius.circular(ThixPolicy.cardRadius),
        border: Border.all(color: ThixPolicy.border, width: ThixPolicy.cardBorderWidth),
        boxShadow: ThixPolicy.shadowSoft(), // Légère ombre Design System
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(ThixPolicy.cardRadius),
        child: Column(
          children: [
            _buildRow(context, 1, 'Cercle 1 – Prioritaire'),
            const Divider(height: 1, indent: 64),
            _buildRow(context, 2, 'Cercle 2 – Secondaire'),
            const Divider(height: 1, indent: 64),
            _buildRow(context, 3, 'Cercle 3 – Urgence'),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(BuildContext context, int level, String title) {
    final circleContacts = contacts.where((c) => c.circle == level).toList();
    final count = circleContacts.length;
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                  color: level == 1 ? ThixPolicy.danger : (isDark ? ThixPolicy.inkDeep : ThixPolicy.surfaceStrong),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    level.toString(),
                    style: ThixPolicy.titleStyle.copyWith(
                      color: level == 1 ? ThixPolicy.onBrand : Theme.of(context).colorScheme.onSurface, 
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
                      style: ThixPolicy.bodyStyle.copyWith(fontWeight: ThixPolicy.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      count == 0 ? 'Aucun secours' : '$count secours',
                      style: ThixPolicy.captionStyle.copyWith(
                        color: count == 0 ? ThixPolicy.danger : ThixPolicy.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              // Miniatures photos (Avatars)
              if (count > 0) _buildAvatars(context, circleContacts),
              if (count > 0) const SizedBox(width: ThixPolicy.s12),
              Icon(Icons.chevron_right, color: ThixPolicy.textMuted),
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
                border: Border.all(color: Theme.of(context).cardColor, width: 2.5), 
              ),
              child: CircleAvatar(
                radius: (avatarSize / 2) - 2.5,
                backgroundColor: ThixPolicy.border,
                backgroundImage: imageUrl != null ? NetworkImage(imageUrl) : null,
                child: imageUrl == null ? const Icon(Icons.person, size: 14, color: ThixPolicy.onBrand) : null,
              ),
            ),
          );
        }).reversed.toList(),
      ),
    );
  }
}

// ───────────────────────── Action Rapide ─────────────────────────
class _QuickActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionChip({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ThixPolicy.rMd),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: ThixPolicy.s16, vertical: ThixPolicy.s12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(ThixPolicy.rMd),
          border: Border.all(color: ThixPolicy.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.onSurface, size: 20),
            const SizedBox(width: ThixPolicy.s8),
            Text(label, style: ThixPolicy.labelStyle),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── Module Pleine Largeur ─────────────────────────
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ThixPolicy.cardRadius),
      child: Container(
        padding: ThixPolicy.cardPaddingLarge,
        decoration: BoxDecoration(
          color: ThixPolicy.danger,
          borderRadius: BorderRadius.circular(ThixPolicy.cardRadius),
          boxShadow: ThixPolicy.shadowSoft(),
        ),
        child: Row(
          children: [
            Icon(icon, color: ThixPolicy.onBrand, size: 36),
            const SizedBox(width: ThixPolicy.s16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: ThixPolicy.titleStyle.copyWith(color: ThixPolicy.onBrand, fontWeight: ThixPolicy.bold)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: ThixPolicy.bodySmallStyle.copyWith(color: ThixPolicy.onBrand.withValues(alpha: 0.9))),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: ThixPolicy.onBrand, size: 16),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── Nav Card Compact ─────────────────────────
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ThixPolicy.cardRadius),
      child: Container(
        padding: ThixPolicy.cardPadding,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(ThixPolicy.cardRadius),
          border: Border.all(color: ThixPolicy.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.onSurface, size: 28),
            const SizedBox(height: ThixPolicy.s12),
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: ThixPolicy.labelStyle),
            const SizedBox(height: 4),
            Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: ThixPolicy.captionStyle),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── Bottom nav ─────────────────────────
class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.currentIndex});
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: ThixPolicy.border)),
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (i) {
          if (i == 0) Navigator.of(context).popUntil((r) => r.isFirst);
        },
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: ThixPolicy.danger, 
        unselectedItemColor: ThixPolicy.textMuted,
        selectedLabelStyle: ThixPolicy.microStyle.copyWith(fontWeight: ThixPolicy.bold),
        unselectedLabelStyle: ThixPolicy.microStyle,
        elevation: 0,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Accueil'),
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: 'Chat'),
          BottomNavigationBarItem(icon: Icon(Icons.sos, size: 28), label: 'SOS'),
          BottomNavigationBarItem(icon: Icon(Icons.map_outlined), label: 'Carte'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profil'),
        ],
      ),
    );
  }
}
