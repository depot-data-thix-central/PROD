import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

import 'package:thix_id/nav.dart';
import '../models/personne_recherchee_model.dart';
import '../providers/recherche_providers.dart';
import '../widgets/alerte_card.dart';
import 'creer_alerte_page.dart';
import 'detail_personne_page.dart';

class MesAlertesPage extends ConsumerWidget {
  const MesAlertesPage({super.key});

  Future<void> _onRetrouver(
    BuildContext context,
    WidgetRef ref,
    PersonneRecherchee p,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Personne retrouvée ?',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        content: Text(
          '« ${p.nomComplet} » sera marquée comme retrouvée et retirée des alertes actives.',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
            ),
            child: const Text('Confirmer',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await ref.read(rechercheServiceProvider).marquerRetrouvee(p.id);
      ref.invalidate(mesAlertesProvider);
      ref.invalidate(alertesActivesProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Alerte marquée comme retrouvée'),
            backgroundColor: Color(0xFF059669),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _onSupprimer(
    BuildContext context,
    WidgetRef ref,
    PersonneRecherchee p,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Supprimer l\'alerte ?',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        content: Text(
          '« ${p.nomComplet} » sera archivée. Cette action est irréversible côté liste publique.',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await ref.read(rechercheServiceProvider).archiverAlerte(p.id);
      // ou: await ref.read(rechercheServiceProvider).supprimerAlerte(p.id);
      ref.invalidate(mesAlertesProvider);
      ref.invalidate(alertesActivesProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Alerte supprimée')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _onModifier(BuildContext context, PersonneRecherchee p) {
    // Pour l’instant : ouvrir la création en mode édition si tu l’ajoutes plus tard.
    // Placeholder : détail
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DetailPersonnePage(personneId: p.id),
      ),
    );
  }

  void _showActions(
    BuildContext context,
    WidgetRef ref,
    PersonneRecherchee p,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.visibility_outlined),
                title: Text('Voir le détail',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push(AppRoutes.thixRechercheDetailPath(p.id));
                },
              ),
              if (p.statut == StatutAlerte.active) ...[
                ListTile(
                  leading: const Icon(Icons.check_circle_outline,
                      color: Color(0xFF059669)),
                  title: Text('Marquer retrouvée',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF059669),
                      )),
                  onTap: () {
                    Navigator.pop(ctx);
                    _onRetrouver(context, ref, p);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: Text('Modifier',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _onModifier(context, p);
                  },
                ),
              ],
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: Text('Supprimer',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      color: Colors.red,
                    )),
                onTap: () {
                  Navigator.pop(ctx);
                  _onSupprimer(context, ref, p);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(mesAlertesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FC),
      appBar: AppBar(
        title: Text(
          'Mes alertes',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              final ok = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => const CreerAlertePage(
                    initialType: TypeAlerte.disparue,
                  ),
                ),
              );
              if (ok == true) {
                ref.invalidate(mesAlertesProvider);
                ref.invalidate(alertesActivesProvider);
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        color: const Color(0xFF2563EB),
        onRefresh: () async {
          ref.invalidate(mesAlertesProvider);
        },
        child: async.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: Color(0xFF2563EB)),
          ),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Erreur: $e\n\nVérifie que tu es connecté.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ),
          data: (list) {
            if (list.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 100),
                  Icon(Icons.person_search, size: 56, color: Colors.grey[300]),
                  const SizedBox(height: 12),
                  Text(
                    'Aucune alerte créée',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      color: Colors.black45,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Les alertes que tu publies apparaissent ici.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.black38,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final ok = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CreerAlertePage(
                              initialType: TypeAlerte.disparue,
                            ),
                          ),
                        );
                        if (ok == true) {
                          ref.invalidate(mesAlertesProvider);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF111827),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                      icon: const Icon(Icons.add, color: Colors.white),
                      label: Text(
                        'Créer une alerte',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }

            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: list.length,
              itemBuilder: (context, i) {
                final p = list[i];
                return Column(
                  children: [
                    AlerteCard(
                      personne: p,
                      onDetails: () {
                        context.push(AppRoutes.thixRechercheDetailPath(p.id));
                      },
                    ),
                    // Actions rapides sous la carte
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          if (p.statut == StatutAlerte.active)
                            TextButton.icon(
                              onPressed: () => _onRetrouver(context, ref, p),
                              icon: const Icon(
                                Icons.check_circle_outline,
                                size: 18,
                                color: Color(0xFF059669),
                              ),
                              label: Text(
                                'Retrouvée',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF059669),
                                ),
                              ),
                            ),
                          TextButton.icon(
                            onPressed: () => _showActions(context, ref, p),
                            icon: const Icon(Icons.more_horiz, size: 18),
                            label: Text(
                              'Actions',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const Spacer(),
                          // Badge statut
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: p.statut == StatutAlerte.active
                                  ? const Color(0xFFDBEAFE)
                                  : p.statut == StatutAlerte.retrouvee
                                      ? const Color(0xFFD1FAE5)
                                      : const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              p.statut == StatutAlerte.active
                                  ? 'Active'
                                  : p.statut == StatutAlerte.retrouvee
                                      ? 'Retrouvée'
                                      : 'Archivée',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: p.statut == StatutAlerte.active
                                    ? const Color(0xFF1D4ED8)
                                    : p.statut == StatutAlerte.retrouvee
                                        ? const Color(0xFF059669)
                                        : Colors.black54,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}
