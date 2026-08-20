import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/recherche_providers.dart';
import 'signaler_page.dart';

class DetailPersonnePage extends ConsumerWidget {
  const DetailPersonnePage({super.key, required this.personneId});
  final String personneId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(personneDetailProvider(personneId));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Détail alerte',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: async.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur: $e')),
        data: (p) {
          if (p == null) {
            return const Center(child: Text('Alerte introuvable'));
          }
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (p.photoUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(p.photoUrl!, height: 220, fit: BoxFit.cover),
                ),
              const SizedBox(height: 16),
              Text(p.nomComplet,
                  style: GoogleFonts.inter(
                      fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(p.badgeLabel,
                  style: GoogleFonts.inter(
                      color: const Color(0xFF1D4ED8),
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(p.metaLine,
                  style: GoogleFonts.inter(color: Colors.black54)),
              const SizedBox(height: 12),
              Text(p.derniereVueLabel,
                  style: GoogleFonts.inter(height: 1.4)),
              if (p.description != null) ...[
                const SizedBox(height: 16),
                Text(p.description!,
                    style: GoogleFonts.inter(height: 1.45)),
              ],
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            SignalerPage(personneId: p.id),
                      ),
                    );
                  },
                  child: Text('Signaler une info',
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
