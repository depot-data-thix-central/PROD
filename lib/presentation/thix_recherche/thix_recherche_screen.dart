import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'models/personne_recherchee_model.dart';
import 'providers/recherche_providers.dart';
import 'widgets/alerte_card.dart';
import 'pages/detail_personne_page.dart';
import 'pages/creer_alerte_page.dart';
import 'pages/mes_alertes_page.dart';

// Palette entreprise
const _bg = Color(0xFFF3F4F6);
const _card = Colors.white;
const _ink = Color(0xFF111827);
const _muted = Color(0xFF6B7280);
const _blue = Color(0xFF1D4ED8);
const _blueSoft = Color(0xFFEFF6FF);
const _border = Color(0xFFE5E7EB);

class ThixRechercheScreen extends ConsumerWidget {
  const ThixRechercheScreen({super.key});

  Future<void> _openCreer(BuildContext context, WidgetRef ref) async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const CreerAlertePage(
          initialType: TypeAlerte.disparue,
        ),
      ),
    );
    if (ok == true) {
      ref.invalidate(alertesActivesProvider);
      ref.invalidate(mesAlertesProvider);
    }
  }

  void _openMesAlertes(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MesAlertesPage()),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filtre = ref.watch(rechercheFiltreProvider);
    final alertesAsync = ref.watch(alertesActivesProvider);

    return Scaffold(
      backgroundColor: _bg,

      // ——— Bouton (+) uniquement — pas de texte long ———
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openCreer(context, ref),
        backgroundColor: _ink,
        elevation: 4,
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),

      body: SafeArea(
        child: Column(
          children: [
            // ——— Header ———
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
              child: Row(
                children: [
                  const SizedBox(width: 44),
                  Expanded(
                    child: Text(
                      'THIX RECHERCHE',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _ink,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  // Cloche → Mes signalements
                  IconButton(
                    tooltip: 'Mes alertes',
                    icon: const Icon(Icons.notifications_outlined, color: _ink),
                    onPressed: () => _openMesAlertes(context),
                  ),
                ],
              ),
            ),

            // ——— Filtres ———
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Row(
                children: [
                  _FilterChip(
                    label: 'Disparues',
                    icon: Icons.person_outline,
                    selected:
                        filtre == null || filtre == TypeAlerte.disparue,
                    filled: true,
                    onTap: () {
                      ref.read(rechercheFiltreProvider.notifier).state =
                          TypeAlerte.disparue;
                      ref.invalidate(alertesActivesProvider);
                    },
                  ),
                  const SizedBox(width: 10),
                  _FilterChip(
                    label: 'Recherchées',
                    icon: Icons.shield_outlined,
                    selected: filtre == TypeAlerte.recherchee,
                    filled: false,
                    onTap: () {
                      ref.read(rechercheFiltreProvider.notifier).state =
                          TypeAlerte.recherchee;
                      ref.invalidate(alertesActivesProvider);
                    },
                  ),
                ],
              ),
            ),

            // ——— Titre + Mes alertes ———
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Alertes actives',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _ink,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _openMesAlertes(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Mes alertes  >',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _blue,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),

            // ——— Liste ———
            Expanded(
              child: RefreshIndicator(
                color: _blue,
                onRefresh: () async {
                  ref.invalidate(alertesActivesProvider);
                },
                child: alertesAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: _blue),
                  ),
                  error: (e, _) => ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      const SizedBox(height: 80),
                      Text(
                        'Erreur de chargement',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(color: Colors.red),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$e',
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: _muted,
                        ),
                      ),
                    ],
                  ),
                  data: (list) {
                    if (list.isEmpty) {
                      return ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          const SizedBox(height: 72),
                          Icon(
                            Icons.person_search,
                            size: 56,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Aucune alerte active',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: _muted,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Appuie sur + pour signaler une disparition',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: Colors.black38,
                            ),
                          ),
                        ],
                      );
                    }

                    return ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                      itemCount: list.length + 1,
                      itemBuilder: (context, i) {
                        if (i == list.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 12, bottom: 8),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: _card,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: _border),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.info_outline,
                                    size: 18,
                                    color: _muted,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Si vous avez des informations, signalez-les en toute sécurité.',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: _muted,
                                        height: 1.35,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
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
    required this.filled,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = selected
        ? (filled ? _ink : _card)
        : _card;
    final fg = selected
        ? (filled ? Colors.white : _ink)
        : _muted;
    final borderColor = selected && !filled
        ? _blue.withOpacity(0.35)
        : _border;

    return Expanded(
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(22),
        elevation: selected ? 1 : 0,
        shadowColor: Colors.black12,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: fg),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: fg,
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
