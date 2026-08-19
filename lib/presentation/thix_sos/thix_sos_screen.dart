/// THIX SOS — Homepage (production)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'models/sos_models.dart';
import 'pages/sos_actif_page.dart';
import 'providers/sos_providers.dart';
import 'widgets/cercle_card.dart';
import 'widgets/sos_button.dart';
import 'widgets/status_banner.dart';

class ThixSosScreen extends ConsumerWidget {
  const ThixSosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contactsAsync = ref.watch(sosContactsProvider);
    final activeAsync = ref.watch(activeSosProvider);
    final triggerState = ref.watch(triggerSosProvider);
    final isTriggering = triggerState.isLoading;

    // Si SOS déjà actif → rediriger
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
      backgroundColor: const Color(0xFF0A0A0F),
      body: SafeArea(
        child: Column(
          children: [
            _Header(),
            Expanded(
              child: RefreshIndicator(
                color: const Color(0xFFEF4444),
                backgroundColor: const Color(0xFF16161F),
                onRefresh: () async {
                  ref.invalidate(sosContactsProvider);
                  ref.invalidate(activeSosProvider);
                  ref.invalidate(sosHistoryProvider);
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  child: Column(
                    children: [
                      // Bannière statut
                      activeAsync.when(
                        data: (incident) => StatusBanner(
                          incident: incident,
                          locationLabel: 'Ma position',
                        ),
                        loading: () => const StatusBanner(),
                        error: (_, __) => const StatusBanner(),
                      ),
                      const SizedBox(height: 28),

                      // Bouton SOS
                      SosButton(
                        enabled: !isTriggering,
                        isLoading: isTriggering,
                        onTriggered: () async {
                          final incident =
                              await ref.read(triggerSosProvider.notifier).trigger();
                          if (incident != null && context.mounted) {
                            // Heartbeat
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
                                ),
                                backgroundColor: const Color(0xFFDC2626),
                              ),
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Appuyez et maintenez 2 secondes\npour déclencher le SOS',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.white38,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Mes secours
                      contactsAsync.when(
                        data: (contacts) => CerclesList(
                          contacts: contacts,
                          onManage: () {
                            // TODO: Navigator → MesSecoursPage
                          },
                          onCircleTap: (circle) {
                            // TODO: Navigator → CercleDetailPage(circle)
                          },
                        ),
                        loading: () => const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: CircularProgressIndicator(
                              color: Color(0xFFEF4444),
                            ),
                          ),
                        ),
                        error: (e, _) => Text(
                          'Erreur secours: $e',
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Actions rapides
                      _sectionTitle('ACTIONS RAPIDES'),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _ActionTile(
                              icon: Icons.location_on_outlined,
                              label: 'Partager\nma position',
                              color: const Color(0xFF34D399),
                              onTap: () {},
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _ActionTile(
                              icon: Icons.timer_outlined,
                              label: 'Safe Check\nJe suis arrivé',
                              color: const Color(0xFFFBBF24),
                              onTap: () {},
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _ActionTile(
                              icon: Icons.route,
                              label: 'Mes trajets\nPartages actifs',
                              color: const Color(0xFF60A5FA),
                              onTap: () {},
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _ActionTile(
                              icon: Icons.history,
                              label: 'Mes incidents\nHistorique SOS',
                              color: const Color(0xFFF87171),
                              onTap: () {},
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Nav cards
                      _NavCard(
                        icon: Icons.chat_bubble_outline,
                        iconColor: const Color(0xFFA78BFA),
                        title: 'THIX CHAT SOS',
                        subtitle: 'Aucun incident actif\nVos conversations d\'urgence',
                        onTap: () {},
                      ),
                      const SizedBox(height: 10),
                      _NavCard(
                        icon: Icons.desktop_windows_outlined,
                        iconColor: const Color(0xFFF87171),
                        title: 'CHAMBRE DE CRISE',
                        subtitle: 'Aucun incident en cours\nAccédez à vos incidents',
                        onTap: () {},
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _BottomNav(currentIndex: 2),
    );
  }

  Widget _sectionTitle(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.white54,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.menu, color: Colors.white70),
            onPressed: () {},
          ),
          Expanded(
            child: Center(
              child: RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: 'THIX ',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    TextSpan(
                      text: 'SOS',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFEF4444),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.white70),
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}

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
      color: const Color(0xFF16161F),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 10),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
      color: const Color(0xFF16161F),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.15),
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
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.white38,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white24),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.currentIndex});
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0A0A0F),
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        backgroundColor: const Color(0xFF0A0A0F),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFFEF4444),
        unselectedItemColor: Colors.white38,
        selectedLabelStyle:
            GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.inter(fontSize: 11),
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
            icon: Icon(Icons.sos, size: 32, color: Color(0xFFEF4444)),
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
        onTap: (_) {},
      ),
    );
  }
}
