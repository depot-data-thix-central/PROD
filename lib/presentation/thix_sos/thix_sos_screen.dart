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

// Palette entreprise
const _bg = Color(0xFF0A0A0F);
const _card = Color(0xFF14141C);
const _cardBorder = Color(0xFF252532);
const _red = Color(0xFFEF4444);
const _redDark = Color(0xFFB91C1C);
const _white = Colors.white;
const _muted = Color(0xFF9CA3AF);

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
            const _Header(),
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
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Bannière statut
                      activeAsync.when(
                        data: (incident) => StatusBanner(
                          incident: incident,
                          locationLabel: 'Ma position',
                          onLocationTap: () {},
                        ),
                        loading: () => const StatusBanner(),
                        error: (_, __) => const StatusBanner(),
                      ),
                      const SizedBox(height: 24),

                      // Bouton SOS
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
                                  err?.toString() ??
                                      'Échec du déclenchement SOS',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                backgroundColor: _redDark,
                              ),
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Maintenir 2 secondes pour déclencher',
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: _muted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Mes secours
                      contactsAsync.when(
                        data: (contacts) => CerclesList(
                          contacts: contacts,
                          onManage: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const MesSecoursPage(),
                              ),
                            );
                          },
                          onCircleTap: (circle) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AjouterSecoursPage(
                                  initialCircle: circle,
                                ),
                              ),
                            ).then((ok) {
                              if (ok == true) {
                                ref.invalidate(sosContactsProvider);
                              }
                            });
                          },
                        ),
                        loading: () => const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(
                            child: CircularProgressIndicator(color: _red),
                          ),
                        ),
                        error: (e, _) => Text(
                          'Erreur secours',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(color: _red),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Actions rapides
                      _SectionLabel('ACTIONS RAPIDES'),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _ActionTile(
                              icon: Icons.location_on_outlined,
                              label: 'Partager position',
                              color: const Color(0xFF34D399),
                              onTap: () => _soon(context, 'Partage de position'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _ActionTile(
                              icon: Icons.timer_outlined,
                              label: 'Safe Check',
                              color: const Color(0xFFFBBF24),
                              onTap: () => _soon(context, 'Safe Check'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _ActionTile(
                              icon: Icons.route_outlined,
                              label: 'Mes trajets',
                              color: const Color(0xFF60A5FA),
                              onTap: () => _soon(context, 'Trajets'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _ActionTile(
                              icon: Icons.history,
                              label: 'Mes incidents',
                              color: _red,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const MesIncidentsPage(),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),

                      // Chat SOS
                      _NavCard(
                        icon: Icons.chat_bubble_outline,
                        iconColor: const Color(0xFFA78BFA),
                        title: 'THIX CHAT SOS',
                        subtitle: activeAsync.maybeWhen(
                          data: (i) => i != null && i.isActive
                              ? 'Incident actif — ouvrir le chat'
                              : 'Conversations d’urgence',
                          orElse: () => 'Conversations d’urgence',
                        ),
                        onTap: () => _soon(context, 'Chat SOS'),
                      ),
                      const SizedBox(height: 10),

                      // Chambre de crise
                      _NavCard(
                        icon: Icons.desktop_windows_outlined,
                        iconColor: _red,
                        title: 'CHAMBRE DE CRISE',
                        subtitle: activeAsync.maybeWhen(
                          data: (i) => i != null && i.isActive
                              ? 'SOS en cours — ouvrir'
                              : 'Aucun incident en cours',
                          orElse: () => 'Aucun incident en cours',
                        ),
                        onTap: () {
                          final incident = activeAsync.valueOrNull;
                          if (incident != null && incident.isActive) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChambreCrisePage(
                                  incidentId: incident.id,
                                ),
                              ),
                            );
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const MesIncidentsPage(),
                              ),
                            );
                          }
                        },
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
        content: Text(
          '$label — bientôt disponible',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: _card,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

// ───────────────────────── Header ─────────────────────────

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.menu, color: _muted),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: Text(
              'THIX SOS',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: _white,
                letterSpacing: 0.5,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: _muted),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Paramètres SOS — bientôt'),
                  backgroundColor: _card,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Section ─────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: _muted,
        letterSpacing: 1.0,
      ),
    );
  }
}

// ───────────────────────── Action tile ─────────────────────────

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          constraints: const BoxConstraints(minHeight: 88),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 10),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _white,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── Nav card ─────────────────────────

class _NavCard extends StatelessWidget {
  const _NavCard({
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
    return Material(
      color: _card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _cardBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: _muted,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFF4B5563), size: 20),
            ],
          ),
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
          if (i == 0) {
            Navigator.of(context).popUntil((r) => r.isFirst);
          } else if (i == currentIndex) {
            return;
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Bientôt disponible'),
                backgroundColor: _card,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        backgroundColor: _bg,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: _red,
        unselectedItemColor: _muted,
        selectedLabelStyle:
            GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.inter(fontSize: 10),
        elevation: 0,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            label: 'Accueil',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            label: 'Chat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.sos, size: 28),
            label: 'SOS',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map_outlined),
            label: 'Carte',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}
