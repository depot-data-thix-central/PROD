// lib/presentation/thix_reservation/bus/pages/client/bus_trip_detail_page.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import '../../data/models/bus_trip_model.dart';

class BusTripDetailPage extends StatefulWidget {
  final BusTripModel? trip;
  final String? tripId;

  const BusTripDetailPage({
    super.key,
    this.trip,
    this.tripId,
  });

  @override
  State<BusTripDetailPage> createState() => _BusTripDetailPageState();
}

class _BusTripDetailPageState extends State<BusTripDetailPage> {
  BusTripModel? _trip;
  bool _loading = true;
  String? _error;

  String _two(int n) {
    if (n < 10) return '0$n';
    return '$n';
  }

  String _hhmm(DateTime d) {
    return '\( {_two(d.hour)}: \){_two(d.minute)}';
  }

  String _date(DateTime d) {
    return '\( {_two(d.day)}/ \){_two(d.month)}/${d.year}';
  }

  @override
  void initState() {
    super.initState();
    _trip = widget.trip;
    if (_trip != null) {
      _loading = false;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _load();
      });
    }
  }

  Future<void> _load() async {
    String id = widget.tripId ?? widget.trip?.id ?? '';
    if (id.isEmpty && mounted) {
      id = GoRouterState.of(context).pathParameters['tripId'] ?? '';
    }
    if (id.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Trajet introuvable';
      });
      return;
    }

    try {
      final res = await Supabase.instance.client
          .from('bus_trips')
          .select()
          .eq('id', id)
          .limit(1);
      final list = res as List;
      if (list.isEmpty) {
        setState(() {
          _loading = false;
          _error = 'Trajet introuvable';
        });
        return;
      }
      setState(() {
        _trip = BusTripModel.fromJson(Map<String, dynamic>.from(list.first));
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null || _trip == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Détail trajet')),
        body: Center(child: Text(_error ?? 'Trajet introuvable')),
      );
    }

    final trip = _trip!;

    return Scaffold(
      backgroundColor: ThixPolicy.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text('${trip.departureCity} → ${trip.arrivalCity}'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_date(trip.departureTime)),
            const SizedBox(height: 8),
            Text(trip.agency?.name ?? 'Agence'),
            const SizedBox(height: 8),
            Text('${_hhmm(trip.departureTime)} ${trip.departureCity}'),
            Text('${_hhmm(trip.arrivalTime)} ${trip.arrivalCity}'),
            const SizedBox(height: 8),
            Text('${trip.availableSeats} places'),
            const SizedBox(height: 8),
            Text('${trip.priceFcfa} CDF'),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: trip.isFull
                ? null
                : () => context.push('/thix-reservation/bus/seats', extra: trip),
            child: Text(trip.isFull ? 'Complet' : 'Choisir sieges'),
          ),
        ),
      ),
    );
  }
}
