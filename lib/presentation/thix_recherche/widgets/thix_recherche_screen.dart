import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'models/personne_recherchee_model.dart';
import 'providers/recherche_providers.dart';
import 'widgets/alerte_card.dart';
import 'pages/detail_personne_page.dart';
import 'pages/signaler_page.dart';

class ThixRechercheScreen extends ConsumerWidget {
  const ThixRechercheScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filtre = ref.watch(rechercheFiltreProvider);
    final alertesAsync = ref.watch(alertesActivesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FC),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: Row(
                children: [
                  const SizedBox(width: 40),
                  Expanded(
                    child: Text(
                      'THIX RECHERCHE',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined),
                    onPressed: () {},
                  ),
                ],
              ),
            ),

            // Filtres Disparues / Recherchées
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  _FilterChip(
                    label: 'Personnes disparues',
                    icon: Icons.person,
                    selected: filtre == null || filtre == TypeAlerte.disparue,
                    dark: filtre == TypeAlerte.disparue || filtre == null,
                    onTap: () {
                      ref.read(rechercheFiltreProvider.notifier).state =
                          TypeAlerte.disparue;
                      ref.invalidate(alertesActivesProvider);
                    },
                  ),
                  const SizedBox(width: 10),
                  _FilterChip(
                    label: 'Personnes recherchées',
                    icon: Icons.shield_outlined,
                    selected: filtre == TypeAlerte.recherchee,
                    dark: false,
                    onTap: () {
                      ref.read(rechercheFiltreProvider.notifier).state =
                          TypeAlerte.recherchee;
                      ref.invalidate(alertesActivesProvider);
                    },
                  ),
                ],
              ),
            ),

            // Titre section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    'Alertes actives',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {},
                    child: Text(
                      'Voir tout  >',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF2563EB),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Liste DB
            Expanded(
              child: RefreshIndicator(
                color: const Color(0xFF2563EB),
                onRefresh: () async {
                  ref.invalidate(alertesActivesProvider);
                },
                child: alertesAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: Color(0xFF2563EB)),
                  ),
                  error: (e, _) => Center(
                    child: Text('Erreur: $e',
                        style: const TextStyle(color: Colors.red)),
                  ),
                  data: (list) {
                    if (list.isEmpty) {
                      return ListView(
                        children: [
                          const SizedBox(height: 80),
                          Icon(Icons.person_search,
                              size: 56, color: Colors.grey[300]),
                          const SizedBox(height: 12),
                          Text(
                            'Aucune alerte active',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              color: Colors.black45,
                            ),
                          ),
                        ],
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: list.length + 1,
                      itemBuilder: (context, i) {
                        if (i == list.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline,
                                    size: 16, color: Colors.black38),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Si vous avez des informations, signalez-les en toute sécurité.',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: Colors.black45,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    // ouvre signalement générique
                                  },
                                  child: Text(
                                    'Signaler  >',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF2563EB),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        final p = list[i];
                        return AlerteCard(
                          personne: p,
                          onDetails: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    DetailPersonnePage(personneId: p.id),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.dark,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final bool dark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: selected
            ? (dark ? const Color(0xFF111827) : Colors.white)
            : Colors.white,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: selected && !dark
                    ? const Color(0xFFEF4444).withOpacity(0.4)
                    : Colors.grey.shade200,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: selected && dark
                      ? Colors.white
                      : (selected
                          ? const Color(0xFFEF4444)
                          : Colors.black54),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: selected && dark
                          ? Colors.white
                          : (selected
                              ? const Color(0xFF111827)
                              : Colors.black54),
                    ),
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
