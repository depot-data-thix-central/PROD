/// THIX SOS — Homepage production (Design Entreprise Épuré)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'models/sos_models.dart';
import 'pages/sos_actif_page.dart';
import 'pages/mes_secours_page.dart';
import 'pages/mes_incidents_page.dart';
import 'pages/chambre_crise_page.dart';
import 'pages/ajouter_secours_page.dart';
import 'providers/sos_providers.dart';
import 'widgets/sos_button.dart';
import 'widgets/nearby_alerts_card.dart';

// --- Palette Entreprise / Dark Mode Strict ---
const _bg = Color(0xFF000000); // Noir pur
const _card = Color(0xFF0A0A0A); // Noir très légèrement surélevé pour les cartes sombres
const _cardBorder = Color(0xFF1A1A1A); // Bordure très subtile
const _red = Color(0xFFE50914); // Rouge urgence pur
const _redDark = Color(0xFF8A050C);
const _white = Colors.white;
const _black = Colors.black; // Utilisé pour le texte sur fond blanc

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
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            const _HeaderOfficiel(),
            Expanded(
              child: RefreshIndicator(
                color: _red,
                backgroundColor: _card,
                onRefresh: () async {
                  ref.invalidate(sosContactsProvider);
                  ref.invalidate(activeSosProvider);
                  ref.invalidate(sosHistoryProvider);
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 28),
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
                                  style: GoogleFonts.inter(color: _white),
                                ),
                                backgroundColor: _redDark,
                              ),
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Appuyer et maintenir 2 secondes',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: _white.withOpacity(0.5),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 40),

                      // --- MES SECOURS (Design Blanc Pur) ---
                      _SectionLabel('MES SECOURS', actionText: 'Gérer', onAction: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const MesSecoursPage()));
                      }),
                      const SizedBox(height: 12),
                      contactsAsync.when(
                        data: (contacts) {
                          return Column(
                            children: [
                              _WhiteCircleCard(
                                title: 'Cercle 1 – Prioritaire',
                                level: 1,
                                count: contacts.where((c) => c.circle == 1).length,
                                onTap: () => _handleCircleTap(context, ref, 1),
                              ),
                              const SizedBox(height: 8),
                              _WhiteCircleCard(
                                title: 'Cercle 2 – Secondaire',
                                level: 2,
                                count: contacts.where((c) => c.circle == 2).length,
                                onTap: () => _handleCircleTap(context, ref, 2),
                              ),
                              const SizedBox(height: 8),
                              _WhiteCircleCard(
                                title: 'Cercle 3 – Urgence',
                                level: 3,
                                count: contacts.where((c) => c.circle == 3).length,
                                onTap: () => _handleCircleTap(context, ref, 3),
                              ),
                            ],
                          );
                        },
                        loading: () => const Center(child: CircularProgressIndicator(color: _red)),
                        error: (e, _) => Text('Erreur secours', style: GoogleFonts.inter(color: _red)),
                      ),
                      const SizedBox(height: 32),

                      // --- ALERTES À PROXIMITÉ ---
                      // Titre géré dans le widget NearbyAlertsCard pour éviter le doublon
                      const NearbyAlertsCard(), 
                      const SizedBox(height: 32),

                      // --- ACTIONS RAPIDES ---
                      _SectionLabel('ACTIONS RAPIDES'),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: [
                            _QuickActionChip(icon: Icons.location_on, label: 'Partager', onTap: () => _soon(context, 'Partager')),
                            const SizedBox(width: 8),
                            _QuickActionChip(icon: Icons.timer, label: 'Safe Check', onTap: () => _soon(context, 'Safe Check')),
                            const SizedBox(width: 8),
                            _QuickActionChip(icon: Icons.route, label: 'Mes trajets', onTap: () => _soon(context, 'Trajets')),
                            const SizedBox(width: 8),
                            _QuickActionChip(icon: Icons.campaign, label: 'Signaler', onTap: () => _soon(context, 'Signaler')),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // --- MODULES (Chambre de crise agrandie) ---
                      // Carte pleine largeur rouge
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
                      const SizedBox(height: 12),
                      // Grille secondaire 
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
                          const SizedBox(width: 12),
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
        content: Text('$label — bientôt disponible', style: GoogleFonts.inter(color: _white)),
        backgroundColor: _cardBorder,
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Icon(Icons.menu, color: _white, size: 28),
          Column(
            children: [
              Text(
                'X THIX',
                style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w900, color: _white, letterSpacing: 1.2),
              ),
              Text(
                'CONNECTER • PROTÉGER • AGIR',
                style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w700, color: _white.withOpacity(0.6), letterSpacing: 1.5),
              ),
            ],
          ),
          Row(
            children: [
              Stack(
                children: [
                  const Icon(Icons.notifications_none_rounded, color: _white, size: 28),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: _red, shape: BoxShape.circle),
                      child: Text('3', style: GoogleFonts.inter(fontSize: 10, color: _white, fontWeight: FontWeight.bold)),
                    ),
                  )
                ],
              ),
              const SizedBox(width: 16),
              const CircleAvatar(
                radius: 16,
                backgroundColor: _cardBorder,
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
          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: _white, letterSpacing: 1.2),
        ),
        if (actionText != null)
          GestureDetector(
            onTap: onAction,
            child: Text(
              actionText!,
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: _white.withOpacity(0.7)),
            ),
          ),
      ],
    );
  }
}

// ───────────────────────── Carte "Mes Secours" Blanche ─────────────────────────
class _WhiteCircleCard extends StatelessWidget {
  final String title;
  final int level;
  final int count;
  final VoidCallback onTap;

  const _WhiteCircleCard({
    required this.title,
    required this.level,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: _white, // Blanc pur
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: level == 1 ? _red : _black, // Accent Rouge ou Noir
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  level.toString(),
                  style: GoogleFonts.inter(color: _white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: _black),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    count == 0 ? 'Aucun secours' : '$count secours',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: count == 0 ? _red : _black.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: _black.withOpacity(0.3)),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── Action Rapide (Icones blanches) ─────────────────────────
class _QuickActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionChip({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _cardBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: _white, size: 20), // Icône strictement blanche
            const SizedBox(width: 8),
            Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: _white)),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── Module Pleine Largeur (Chambre de Crise) ─────────────────────────
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
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _red, // Rouge urgence
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, color: _white, size: 36),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900, color: _white)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: _white.withOpacity(0.9))),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: _white, size: 16),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── Nav Card Compact (Icones blanches) ─────────────────────────
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
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: _white, size: 28), // Icône strictement blanche
            const SizedBox(height: 12),
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: _white)),
            const SizedBox(height: 4),
            Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 10, color: _white.withOpacity(0.5), height: 1.3)),
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
        color: _bg,
        border: Border(top: BorderSide(color: _cardBorder)),
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (i) {
          if (i == 0) Navigator.of(context).popUntil((r) => r.isFirst);
        },
        backgroundColor: _bg,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: _white, 
        unselectedItemColor: _white.withOpacity(0.4),
        selectedLabelStyle: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700),
        unselectedLabelStyle: GoogleFonts.inter(fontSize: 10),
        elevation: 0,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Accueil'),
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: 'Chat'),
          BottomNavigationBarItem(icon: Icon(Icons.sos, size: 28, color: _red), label: 'SOS'),
          BottomNavigationBarItem(icon: Icon(Icons.map_outlined), label: 'Carte'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profil'),
        ],
      ),
    );
  }
}
