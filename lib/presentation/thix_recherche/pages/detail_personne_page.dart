import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/personne_recherchee_model.dart';
import '../providers/recherche_providers.dart';
import 'signaler_page.dart';

class DetailPersonnePage extends ConsumerWidget {
  const DetailPersonnePage({super.key, required this.personneId});

  final String personneId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(personneDetailProvider(personneId));

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FC),
      appBar: AppBar(
        title: Text(
          'Détail alerte',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: async.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFF2563EB)),
        ),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Erreur: $e',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ),
        data: (p) {
          if (p == null) {
            return Center(
              child: Text(
                'Alerte introuvable',
                style: GoogleFonts.inter(color: Colors.black54),
              ),
            );
          }
          return _DetailBody(personne: p);
        },
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.personne});

  final PersonneRecherchee personne;

  List<String> get _photos {
    if (personne.photoUrls.isNotEmpty) return personne.photoUrls;
    if (personne.photoUrl != null && personne.photoUrl!.isNotEmpty) {
      return [personne.photoUrl!];
    }
    return const [];
  }

  bool get _isWanted => personne.typeAlerte == TypeAlerte.recherchee;

  Future<void> _openMaps(BuildContext context) async {
    final lat = personne.latitude;
    final lng = personne.longitude;
    if (lat == null || lng == null) return;

    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d\'ouvrir la carte')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final photos = _photos;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              // ——— Galerie ———
              if (photos.isNotEmpty)
                SizedBox(
                  height: 240,
                  child: PageView.builder(
                    itemCount: photos.length,
                    itemBuilder: (_, i) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.network(
                            photos[i],
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: const Color(0xFFE5E7EB),
                              child: const Icon(
                                Icons.person,
                                size: 64,
                                color: Colors.black26,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                )
              else
                Container(
                  height: 180,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(
                    child: Icon(Icons.person, size: 64, color: Colors.black26),
                  ),
                ),

              if (photos.length > 1) ...[
                const SizedBox(height: 8),
                Text(
                  '${photos.length} photos — glisse pour voir',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Colors.black45,
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // ——— Badges ———
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Badge(
                    label: personne.badgeLabel,
                    color: _isWanted
                        ? const Color(0xFF7F1D1D)
                        : const Color(0xFF1D4ED8),
                    bg: _isWanted
                        ? const Color(0xFFFEE2E2)
                        : const Color(0xFFDBEAFE),
                  ),
                  if (personne.categorie != null)
                    _Badge(
                      label: personne.categorie!.labelFr,
                      color: const Color(0xFF374151),
                      bg: const Color(0xFFF3F4F6),
                    ),
                  _Badge(
                    label: personne.timeAgoLabel(),
                    color: Colors.black54,
                    bg: const Color(0xFFF3F4F6),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // ——— Identité ———
              Text(
                personne.nomComplet,
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                ),
              ),
              if (personne.metaLine.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  personne.metaLine,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.black54,
                  ),
                ),
              ],

              const SizedBox(height: 20),
              _SectionTitle('Dernière localisation'),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.place,
                          size: 18,
                          color: Color(0xFF2563EB),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            personne.derniereVueLabel,
                            style: GoogleFonts.inter(height: 1.4, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                    if (personne.latitude != null &&
                        personne.longitude != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        'GPS: ${personne.latitude!.toStringAsFixed(5)}, '
                        '${personne.longitude!.toStringAsFixed(5)}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () => _openMaps(context),
                        icon: const Icon(Icons.map_outlined, size: 18),
                        label: Text(
                          'Ouvrir dans Maps',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              if (personne.description != null &&
                  personne.description!.trim().isNotEmpty) ...[
                const SizedBox(height: 20),
                _SectionTitle('Description'),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Text(
                    personne.description!,
                    style: GoogleFonts.inter(height: 1.5, fontSize: 14),
                  ),
                ),
              ],

              // ——— Avertissement ———
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Text(
                  _isWanted
                      ? '⚠️ NE PAS INTERVENIR DIRECTEMENT\n'
                          'Si vous reconnaissez cette personne, ne tentez pas '
                          'de l\'interpeller. Transmettez l\'information aux autorités.'
                      : '⚠️ Si vous avez des informations, signalez-les. '
                          'Ne prenez aucun risque inutile.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    height: 1.45,
                    color: const Color(0xFF991B1B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),

        // ——— CTA bas ———
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          SignalerPage(personneId: personne.id),
                    ),
                  );
                },
                child: Text(
                  'Signaler une information',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: Colors.black87,
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    required this.color,
    required this.bg,
  });

  final String label;
  final Color color;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}
