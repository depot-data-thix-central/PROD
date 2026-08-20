import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

import 'package:thix_id/nav.dart';
import '../providers/recherche_providers.dart';
import '../widgets/alerte_card.dart';

class MesAlertesPage extends ConsumerWidget {
  const MesAlertesPage({super.key});

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
            onPressed: () => context.push(AppRoutes.thixRechercheCreer),
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
            child: Text('Erreur: $e', style: const TextStyle(color: Colors.red)),
          ),
          data: (list) {
            if (list.isEmpty) {
              return ListView(
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
                  const SizedBox(height: 16),
                  Center(
                    child: ElevatedButton(
                      onPressed: () =>
                          context.push(AppRoutes.thixRechercheCreer),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                      ),
                      child: Text(
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
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: list.length,
              itemBuilder: (context, i) {
                final p = list[i];
                return AlerteCard(
                  personne: p,
                  onDetails: () {
                    context.push(AppRoutes.thixRechercheDetailPath(p.id));
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}
