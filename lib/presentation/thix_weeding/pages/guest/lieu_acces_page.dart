// lib/presentation/thix_weeding/pages/guest/lieu_acces_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/wedding_provider.dart';

class LieuAccesPage extends ConsumerWidget {
  final String weddingId;
  const LieuAccesPage({super.key, required this.weddingId});

  Future<void> _openMap(BuildContext context, double lat, double lng, String label) async {
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Impossible d’ouvrir la carte')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weddingAsync = ref.watch(guestWeddingProvider(weddingId));

    return Scaffold(
      appBar: AppBar(title: const Text('Lieu & Accès'), leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () { if (context.mounted) context.pop(); })),
      body: weddingAsync.when(
        data: (wedding) {
          return CustomScrollView(
            slivers: [
              // MAP PREVIEW
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.all(16),
                  height: 220,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), color: Colors.grey.shade200, image: DecorationImage(image: NetworkImage('https://maps.googleapis.com/maps/api/staticmap?center=${wedding.latitude},${wedding.longitude}&zoom=15&size=600x300&key=YOUR_KEY'), fit: BoxFit.cover, onError: (_, __) {})),
                  child: Stack(
                    children: [
                      Positioned.fill(child: Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), color: Colors.black.withOpacity(0.1)))),
                      Center(child: Icon(Icons.location_on, size: 48, color: const Color(0xFFE25A6A))),
                      Positioned(bottom: 12, right: 12, child: FilledButton.icon(onPressed: () => _openMap(context, wedding.latitude, wedding.longitude, wedding.locationName), icon: const Icon(Icons.directions, size: 18), label: const Text('Itinéraire'))),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList.list(children: [
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [CircleAvatar(backgroundColor: Colors.pink.shade50, child: const Icon(Icons.location_on, color: Colors.pink)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(wedding.locationName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), Text(wedding.locationAddress, style: const TextStyle(color: Colors.grey))]))]),
                          const SizedBox(height: 16),
                          Row(children: [
                            Expanded(child: OutlinedButton.icon(onPressed: () => _openMap(context, wedding.latitude, wedding.longitude, wedding.locationName), icon: const Icon(Icons.navigation), label: const Text('Itinéraire'))),
                            const SizedBox(width: 12),
                            Expanded(child: OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.share), label: const Text('Partager'))),
                          ]),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _InfoTile(icon: Icons.local_parking, title: 'Parking', subtitle: 'Parking disponible à partir de 15h, places limitées'),
                  _InfoTile(icon: Icons.hotel_outlined, title: 'Hébergement', subtitle: 'Hôtel partenaire à 200m - code promo MARIAGE+'),
                  _InfoTile(icon: Icons.checkroom_outlined, title: 'Dress code', subtitle: 'Tenue chic, couleurs claires recommandées'),
                  const SizedBox(height: 24),
                  SizedBox(width: double.infinity, height: 52, child: FilledButton.icon(onPressed: () => _openMap(context, wedding.latitude, wedding.longitude, wedding.locationName), icon: const Icon(Icons.directions), label: const Text('Ouvrir dans Google Maps'), style: FilledButton.styleFrom(backgroundColor: const Color(0xFFE25A6A)))),
                ]),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur: $e')),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _InfoTile({required this.icon, required this.title, required this.subtitle});
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
      child: ListTile(leading: CircleAvatar(backgroundColor: Colors.pink.shade50, child: Icon(icon, color: Colors.pink, size: 20)), title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)), subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey))),
    );
  }
}
