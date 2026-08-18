// lib/presentation/thix_reservation/bus/pages/client/bus_search_result_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/bus_search_provider.dart';
import '../../widgets/client/agency_trip_card.dart';
import '../../widgets/client/bus_filter_bottom_sheet.dart';

class BusSearchResultPage extends StatefulWidget {
  const BusSearchResultPage({super.key});
  @override
  State<BusSearchResultPage> createState() => _BusSearchResultPageState();
}

class _BusSearchResultPageState extends State<BusSearchResultPage> {
  @override
  void initState() {
    super.initState();
    // Si on arrive sans recherche, on lance avec les valeurs par défaut
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = context.read<BusSearchProvider>();
      if (p.filteredResults.isEmpty &&!p.isSearching) {
        p.search();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BusSearchProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${provider.departureCity?? '-'} → ${provider.arrivalCity?? '-'}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0A3D62))),
          Text('${provider.departureDate.day} Mai • ${provider.passengers} passager(s) • ${provider.filteredResults.length} trajets', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        ]),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
        actions: [
          IconButton(icon: const Icon(Icons.tune), onPressed: () => showModalBottomSheet(context: context, isScrollControlled: true, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), builder: (_) => const BusFilterBottomSheet())),
        ],
      ),
      body: Column(
        children: [
          // Barre de tri SaaS
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(children: [
              const Text('Trier par:', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(width: 8),
              _SortChip(label: 'Départ', value: 'departure'),
              const SizedBox(width: 6),
              _SortChip(label: 'Prix', value: 'price'),
              const SizedBox(width: 6),
              _SortChip(label: 'Places', value: 'duration'),
            ]),
          ),
          Expanded(
            child: Builder(builder: (_) {
              if (provider.isSearching) {
                return const Center(child: CircularProgressIndicator());
              }
              if (provider.error!= null) {
                return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.error_outline, size: 48, color: Colors.red), const SizedBox(height: 12), Text(provider.error!, textAlign: TextAlign.center), const SizedBox(height: 12), ElevatedButton(onPressed: () => provider.search(), child: const Text('Réessayer'))]));
              }
              if (provider.filteredResults.isEmpty) {
                return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.search_off, size: 64, color: Colors.grey.shade400), const SizedBox(height: 12), const Text('Aucun trajet trouvé', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), const SizedBox(height: 6), Text('Essayez une autre date ou destination', style: TextStyle(color: Colors.grey.shade600)), const SizedBox(height: 16), OutlinedButton(onPressed: () => provider.clearFilters(), child: const Text('Effacer les filtres'))]));
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: provider.filteredResults.length,
                itemBuilder: (_, i) {
                  final trip = provider.filteredResults[i];
                  return AgencyTripCard(
                    trip: trip,
                    onTap: () => context.push('/thix-reservation/bus/trip/${trip.id}', extra: trip),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _SortChip extends StatelessWidget {
  final String label; final String value;
  const _SortChip({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BusSearchProvider>();
    final selected = provider.sortBy == value;
    return ChoiceChip(label: Text(label, style: TextStyle(fontSize: 12, color: selected? Colors.white: Colors.black87)), selected: selected, selectedColor: const Color(0xFF0D47A1), onSelected: (_) => provider.setSort(value));
  }
}
