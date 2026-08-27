// lib/presentation/thix_reservation/bus/pages/agency/agency_seats_page.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AgencySeatsPage extends StatefulWidget {
  final String tripId;
  const AgencySeatsPage({super.key, required this.tripId});
  @override
  State<AgencySeatsPage> createState() => _AgencySeatsPageState();
}

class _AgencySeatsPageState extends State<AgencySeatsPage> {
  bool _loading = true;
  List<Map<String, dynamic>> _seats = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await Supabase.instance.client
          .from('bus_seats')
          .select()
          .eq('trip_id', widget.tripId)
          .order('seat_number');
      setState(() {
        _seats = List<Map<String, dynamic>>.from(res as List);
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _toggle(Map<String, dynamic> seat) async {
    final next = seat['status'] == 'blocked' ? 'available' : 'blocked';
    await Supabase.instance.client.from('bus_seats').update({'status': next}).eq('id', seat['id']);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion des places', style: TextStyle(fontWeight: FontWeight.w800)),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _seats.isEmpty
              ? const Center(child: Text('Aucun siège généré pour ce trajet'))
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemCount: _seats.length,
                  itemBuilder: (_, i) {
                    final s = _seats[i];
                    final status = (s['status'] ?? 'available').toString();
                    Color c = Colors.green;
                    if (status == 'reserved' || status == 'sold') c = Colors.red;
                    if (status == 'blocked') c = Colors.grey;
                    return InkWell(
                      onTap: status == 'available' || status == 'blocked' ? () => _toggle(s) : null,
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: c.withOpacity(0.15), border: Border.all(color: c), borderRadius: BorderRadius.circular(8)),
                        child: Text('${s['seat_number'] ?? i + 1}', style: TextStyle(fontWeight: FontWeight.w800, color: c)),
                      ),
                    );
                  },
                ),
    );
  }
}
