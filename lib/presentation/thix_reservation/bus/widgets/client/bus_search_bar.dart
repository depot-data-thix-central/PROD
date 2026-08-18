// lib/presentation/thix_reservation/bus/widgets/client/bus_search_bar.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/bus_search_provider.dart';

class BusSearchBar extends StatelessWidget {
  final VoidCallback onSearch;
  const BusSearchBar({super.key, required this.onSearch});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BusSearchProvider>();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _CityField(label: 'Départ', value: provider.departureCity, icon: Icons.my_location, onTap: () => _showCityPicker(context, true))),
              Container(margin: const EdgeInsets.symmetric(horizontal: 8), decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle), child: IconButton(icon: const Icon(Icons.swap_horiz, color: Color(0xFF0A3D62)), onPressed: provider.swapCities)),
              Expanded(child: _CityField(label: 'Arrivée', value: provider.arrivalCity, icon: Icons.location_on, onTap: () => _showCityPicker(context, false))),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _InfoField(label: 'Date de départ', value: '${provider.departureDate.day} Mai ${provider.departureDate.year}', icon: Icons.calendar_today_outlined, onTap: () async {
                final picked = await showDatePicker(context: context, initialDate: provider.departureDate, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 90)));
                if (picked != null) provider.setDate(picked);
              })),
              const SizedBox(width: 12),
              Expanded(child: _InfoField(label: 'Passagers', value: '${provider.passengers} Passager', icon: Icons.person_outline, onTap: () {
                showModalBottomSheet(context: context, builder: (_) => _PassengerSheet());
              })),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, height: 52, child: ElevatedButton.icon(onPressed: onSearch, icon: const Icon(Icons.search, color: Colors.white), label: const Text('Rechercher un bus', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D47A1), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))),
        ],
      ),
    );
  }

  void _showCityPicker(BuildContext context, bool isDeparture) {
    final provider = context.read<BusSearchProvider>();
    showModalBottomSheet(context: context, isScrollControlled: true, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), builder: (_) {
      return DraggableScrollableSheet(expand: false, initialChildSize: 0.6, builder: (_, ctrl) {
        return ListView.builder(controller: ctrl, itemCount: provider.cities.length, itemBuilder: (_, i) {
          final city = provider.cities[i];
          return ListTile(title: Text(city.name), onTap: () {
            if (isDeparture) provider.setDeparture(city.name); else provider.setArrival(city.name);
            Navigator.pop(context);
          });
        });
      });
    });
  }
}

class _CityField extends StatelessWidget {
  final String label; final String? value; final IconData icon; final VoidCallback onTap;
  const _CityField({required this.label, required this.value, required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(onTap: onTap, child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12), decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)), child: Row(children: [Icon(icon, size: 18, color: const Color(0xFF0D47A1)), const SizedBox(width: 8), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)), Text(value?? 'Choisir', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), overflow: TextOverflow.ellipsis)])) ])));
  }
}

class _InfoField extends StatelessWidget {
  final String label; final String value; final IconData icon; final VoidCallback onTap;
  const _InfoField({required this.label, required this.value, required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(onTap: onTap, child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)), child: Row(children: [Icon(icon, size: 18, color: const Color(0xFF0D47A1)), const SizedBox(width: 8), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)), Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))]))])));
  }
}

class _PassengerSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final p = context.watch<BusSearchProvider>();
    return Container(
      padding: const EdgeInsets.all(20), 
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('Nombre de passagers', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), 
        const SizedBox(height: 20), 
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton.filledTonal(onPressed: () => p.setPassengers(p.passengers-1), icon: const Icon(Icons.remove)), 
          Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Text('${p.passengers}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold))), 
          IconButton.filledTonal(onPressed: () => p.setPassengers(p.passengers+1), icon: const Icon(Icons.add))
        ]), 
        const SizedBox(height: 20), 
        SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Confirmer')))
      ])
    );
  }
}
