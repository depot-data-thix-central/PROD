// lib/presentation/thix_sante/patient/screens/urgences_proches_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/thix_sante_colors.dart';

class UrgencesProchesPage extends ConsumerWidget {
  const UrgencesProchesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFFFEF2F2),
      appBar: AppBar(
        backgroundColor: ThixSanteColors.danger,
        foregroundColor: Colors.white,
        title: const Text(
          'URGENCES',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: ThixSanteColors.danger.withOpacity(0.3),
              ),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.emergency,
                  color: ThixSanteColors.danger,
                  size: 40,
                ),
                const SizedBox(height: 8),
                // CORRECTION ICI : Utilisation des guillemets doubles
                const Text(
                  "Besoin d'aide immédiate?", 
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.call),
                    label: const Text('Appeler 112 / SAMU'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ThixSanteColors.danger,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.share_location),
                    label: const Text('Partager ma position'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Services proches',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          ...[
            {
              'n': 'Urgences Générales - Hôpital Général',
              'd': '0.6 km',
              't': 'Ouvert 24/7'
            },
            {
              'n': 'Cardio Urgence',
              'd': '1.1 km',
              't': 'Ouvert 24/7'
            },
            {
              'n': 'Maternité Urgence',
              'd': '1.8 km',
              't': 'Ouvert 24/7'
            }
          ].map((e) => Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFFEF2F2),
                    child: Icon(
                      Icons.local_hospital,
                      color: ThixSanteColors.danger,
                    ),
                  ),
                  title: Text(
                    e['n']!,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text('${e['d']} • ${e['t']}'),
                  trailing: const Icon(
                    Icons.directions,
                    color: ThixSanteColors.danger,
                  ),
                ),
              )),
        ],
      ),
    );
  }
}
