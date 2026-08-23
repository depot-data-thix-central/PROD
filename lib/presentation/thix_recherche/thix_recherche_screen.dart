// lib/presentation/recherche/thix_recherche_screen.dart

import 'dart:ui'; // Nécessaire pour l'effet de flou (Glassmorphism)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'models/personne_recherchee_model.dart';
import 'providers/recherche_providers.dart';
import 'widgets/alerte_card.dart';
import 'pages/detail_personne_page.dart';
import 'pages/creer_alerte_page.dart';
import 'pages/mes_alertes_page.dart';

// === PALETTE PREMIUM / GLASSMORPHISM & RDC / OR ===
const _bgDeep = Color(0xFF040A18); // Deep Navy très profond
const _gold = Color(0xFFFFD100); // Jaune / Or Premium
const _cardGlass = Color(0x12FFFFFF); // Effet verre (Blanc transparent)
const _cardGlassSelected = Color(0x26FFFFFF); // Verre sélectionné
const _borderGlass = Color(0x33FFFFFF); // Bordure subtile en verre
const _muted = Colors.white60;
const _blueAccent = Color(0xFF3B82F6);

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
      backgroundColor: _bgDeep,

      // ——— Bouton d'action flottant (Style Or / Navy) ———
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openCreer(context, ref),
        backgroundColor: _gold,
        elevation: 6,
        child: const Icon(Icons.add, color: _bgDeep, size: 28),
      ),

      body: SafeArea(
        child: Stack(
          children: [
            // Effets lumineux en arrière-plan (Orbs abstraits)
            Positioned(
              top: -50,
              left: -50,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(shape: BoxShape.circle, color: _blueAccent.withOpacity(0.3)),
                child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 70, sigmaY: 70), child: Container()),
              ),
            ),
            Positioned(
              top: 250,
              right: -80,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(shape: BoxShape.circle, color: _gold.withOpacity(0.15)),
                child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 70, sigmaY: 70), child: Container()),
              ),
            ),

            Column(
              children: [
                // ——— Header ———
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    children: [
                      const SizedBox(width: 40),
                      Expanded(
                        child: Text(
                          'THIX RECHERCHE',
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      // Cloche → Mes signalements
                      IconButton(
                        tooltip: 'Mes alertes',
                        icon: const Icon(Icons.notifications_outlined, color: _gold),
                        onPressed: () => _openMesAlertes(context),
                      ),
                    ],
                  ),
                ),

                // ——— Filtres en Verre Dépoli (Glassmorphism) ———
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                  child: Row(
                    children: [
                      _FilterChip(
                        label: 'Disparues',
                        icon: Icons.person_outline,
                        selected: filtre == null || filtre == TypeAlerte.disparue,
                        filled: true,
                        onTap: () {
                          ref.read(rechercheFiltreProvider.notifier).state = TypeAlerte.disparue;
                          ref.invalidate(alertesActivesProvider);
                        },
                      ),
                      const SizedBox(width: 12),
                      _FilterChip(
                        label: 'Recherchées',
                        icon: Icons.shield_outlined,
                        selected: filtre == TypeAlerte.recherchee,
                        filled: false,
                        onTap: () {
                          ref.read(rechercheFiltreProvider.notifier).state = TypeAlerte.recherchee;
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
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white70,
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
                            fontWeight: FontWeight.w700,
                            color: _gold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // ——— Liste ———
                Expanded(
                  child: RefreshIndicator(
                    color: _gold,
                    backgroundColor: _bgDeep,
                    onRefresh: () async {
                      ref.invalidate(alertesActivesProvider);
                    },
                    child: alertesAsync.when(
                      loading: () => const Center(
                        child: CircularProgressIndicator(color: _gold),
                      ),
                      error: (e, _) => ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          const SizedBox(height: 80),
                          Text(
                            'Erreur de chargement',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(color: Colors.redAccent),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '$e',
                            textAlign: TextAlign.center,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(fontSize: 12, color: _muted),
                          ),
                        ],
                      ),
                      data: (list) {
                        if (list.isEmpty) {
                          return ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              const SizedBox(height: 72),
                              const Icon(Icons.person_search, size: 56, color: Colors.white24),
                              const SizedBox(height: 12),
                              Text(
                                'Aucune alerte active',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white70,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Appuie sur + pour signaler une disparition',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(fontSize: 13, color: Colors.white38),
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
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: _cardGlass,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: _borderGlass),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.info_outline, size: 18, color: _gold),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              'Si vous avez des informations, signalez-les en toute sécurité.',
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.inter(
                                                fontSize: 12,
                                                color: Colors.white70,
                                                height: 1.35,
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

                            final p = list[i];
                            return AlerteCard(
                              personne: p,
                              onDetails: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => DetailPersonnePage(personneId: p.id),
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
    // Style Glassmorphism pour les puces de filtres
    final bg = selected ? (filled ? _gold : _cardGlassSelected) : _cardGlass;
    final fg = selected ? (filled ? _bgDeep : Colors.white) : Colors.white60;
    final borderColor = selected ? _gold : _borderGlass;

    return Expanded(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Material(
            color: bg,
            borderRadius: BorderRadius.circular(22),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(22),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: borderColor, width: selected ? 1.5 : 1),
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
                          fontWeight: FontWeight.w800,
                          color: fg,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
