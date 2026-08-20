/// THIX SOS — Homepage production (design entreprise)
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
import 'widgets/cercle_card.dart';
import 'widgets/sos_button.dart';
import 'widgets/status_banner.dart';

 import 'widgets/nearby_alerts_card.dart'; 

// --- Palette Entreprise / Dark Mode ---
const _bg = Color(0xFF030508); // Vrai noir (fond)
const _card = Color(0xFF0E121B); // Bleu/Gris très profond
const _cardBorder = Color(0xFF1C2333); // Bordure subtile et nette
const _red = Color(0xFFE50914); // Rouge urgence pur
const _redDark = Color(0xFF8A050C);
const _green = Color(0xFF10B981);
const _accent = Color(0xFF3B82F6);
const _white = Colors.white;
const _muted = Color(0xFF8B94A3); // Gris bleuté pour le texte secondaire

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
            const _HeaderOfficiel(), // Nouvel en-tête basé sur ton design
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
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Bannière statut (Verte = Sécurité)
                      activeAsync.when(
                        data: (incident) => StatusBanner(
                          incident: incident,
                          locationLabel: 'Ma position',
                          onLocationTap: () {},
                        ),
                        loading: () => const StatusBanner(),
                        error: (_, __) => const StatusBanner(),
                      ),
                      const SizedBox(height: 28),

                      // Bouton SOS Central
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
                          color: _muted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Mes Secours (Cercles)
                      _SectionLabel('MES SECOURS', actionText: 'Gérer', onAction: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const MesSecoursPage()));
                      }),
                      const SizedBox(height: 12),
                      contactsAsync.when(
                        data: (contacts) => CerclesList(
                          contacts: contacts,
                          onManage: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MesSecoursPage())),
                          onCircleTap: (circle) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => AjouterSecoursPage(initialCircle: circle)),
                            ).then((ok) {
                              if (ok == true) ref.invalidate(sosContactsProvider);
                            });
                          },
                        ),
                        loading: () => const Center(child: CircularProgressIndicator(color: _red)),
                        error: (e, _) => Text('Erreur secours', style: GoogleFonts.inter(color: _red)),
                      ),
                      const SizedBox(height: 28),

                      // --- NOUVEAU : Alertes à proximité (Carte) ---
                      _SectionLabel('ALERTES À PROXIMITÉ', actionText: 'Voir sur la carte', onAction: () => _soon(context, 'Carte')),
                      const SizedBox(height: 12),
                      NearbyAlertsCard(), // Le widget demandé inséré ici
                      const SizedBox(height: 28),

                      // --- NOUVEAU : Actions Rapides (Scroll Horizontal) ---
                      _SectionLabel('ACTIONS RAPIDES'),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: [
                            _QuickActionChip(icon: Icons.location_on, label: 'Partager', color: _green, onTap: () => _soon(context, 'Partager')),
                            const SizedBox(width: 8),
                            _QuickActionChip(icon: Icons.timer, label: 'Safe Check', color: Colors.orange, onTap: () => _soon(context, 'Safe Check')),
                            const SizedBox(width: 8),
                            _QuickActionChip(icon: Icons.route, label: 'Mes trajets', color: Colors.purpleAccent, onTap: () => _soon(context, 'Trajets')),
                            const SizedBox(width: 8),
                            _QuickActionChip(icon: Icons.campaign, label: 'Signaler', color: _red, onTap: () => _soon(context, 'Signaler')),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),

                      // --- NOUVEAU : Grille 2x2 des modules Thix ---
                      Row(
                        children: [
                          Expanded(
                            child: _NavCardCompact(
                              icon: Icons.chat_bubble_rounded,
                              iconColor: Colors.purpleAccent,
                              title: 'THIX CHAT SOS',
                              subtitle: 'Conversations d\'urgence',
                              onTap: () => _soon(context, 'Chat SOS'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _NavCardCompact(
                              icon: Icons.shield,
                              iconColor: _accent,
                              title: 'CHAMBRE DE CRISE',
                              subtitle: 'Accédez à vos incidents',
                              onTap: () {
                                final incident = activeAsync.valueOrNull;
                                if (incident != null && incident.isActive) {
                                  Navigator.push(context, MaterialPageRoute(builder: (_) => ChambreCrisePage(incidentId: incident.id)));
                                } else {
                                  Navigator.push(context, MaterialPageRoute(builder: (_) => const MesIncidentsPage()));
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _NavCardCompact(
                              icon: Icons.search_rounded,
                              iconColor: Colors.amber,
                              title: 'THIX RECHERCHE',
                              subtitle: 'Avis officiels & disparitions',
                              onTap: () => _soon(context, 'Thix Recherche'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _NavCardCompact(
                              icon: Icons.folder_special,
                              iconColor: Colors.teal,
                              title: 'MES INCIDENTS',
                              subtitle: 'Historique et rapports',
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

// ───────────────────────── NOUVEAU : Header Officiel ─────────────────────────
class _HeaderOfficiel extends StatelessWidget {
  const _HeaderOfficiel();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(Icons.menu, color: _white, size: 28),
          // Logo texte stylisé (Peut être remplacé par un Image.asset si tu as le logo X THIX)
          Column(
            children: [
              Text(
                'X THIX',
                style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w900, color: _white, letterSpacing: 1.2),
              ),
              Text(
                'CONNECTER • PROTÉGER • AGIR',
                style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w600, color: _muted, letterSpacing: 1.5),
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
                backgroundImage: NetworkImage('https://i.pravatar.cc/150?img=11'), // Avatar placeholder
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Section Label (avec Action optionnelle) ─────────────────────────
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
          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: _muted, letterSpacing: 1.2),
        ),
        if (actionText != null)
          GestureDetector(
            onTap: onAction,
            child: Text(
              actionText!,
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: _accent),
            ),
          ),
      ],
    );
  }
}

// ───────────────────────── NOUVEAU : Action Rapide (Chip) ─────────────────────────
class _QuickActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionChip({required this.icon, required this.label, required this.color, required this.onTap});

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
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: _white)),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── Nav Card (Format Grille 2x2 Épuré) ─────────────────────────
class _NavCardCompact extends StatelessWidget {
  const _NavCardCompact({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
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
            Icon(icon, color: iconColor, size: 28),
            const SizedBox(height: 12),
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: _white)),
            const SizedBox(height: 4),
            Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 10, color: _muted, height: 1.3)),
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
        selectedItemColor: _white, // Le menu sélectionné est blanc pour contraster
        unselectedItemColor: _muted,
        selectedLabelStyle: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700),
        unselectedLabelStyle: GoogleFonts.inter(fontSize: 10),
        elevation: 0,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Accueil'),
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: 'Chat'),
          BottomNavigationBarItem(icon: Icon(Icons.sos, size: 28, color: _red), label: 'SOS'), // L'icône SOS reste rouge
          BottomNavigationBarItem(icon: Icon(Icons.map_outlined), label: 'Carte'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profil'),
        ],
      ),
    );
  }
}
