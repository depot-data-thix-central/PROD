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
  String _fx = 'CDF';
  static const double usdToCdf = 2850;

  @override
  void initState() {
    super.initState();
    _trip = widget.trip;
    if (_trip != null) {
      _loading = false;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
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
      Map<String, dynamic>? row;

      try {
        final res = await Supabase.instance.client
            .from('bus_trips')
            .select('*, bus_agencies(*)')
            .eq('id', id)
            .limit(1);
        final list = res as List;
        if (list.isNotEmpty) {
          row = Map<String, dynamic>.from(list.first);
        }
      } catch (_) {}

      if (row == null) {
        final res = await Supabase.instance.client
            .from('bus_trips')
            .select('*, agencies(*)')
            .eq('id', id)
            .limit(1);
        final list = res as List;
        if (list.isNotEmpty) {
          row = Map<String, dynamic>.from(list.first);
        }
      }

      if (row == null) {
        setState(() {
          _loading = false;
          _error = 'Trajet introuvable';
        });
        return;
      }

      if (row['agencies'] == null && row['bus_agencies'] != null) {
        row['agencies'] = row['bus_agencies'];
      }

      setState(() {
        _trip = BusTripModel.fromJson(row!);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  String _money(int amountCdf) {
    if (_fx == 'USD') {
      return '${(amountCdf / usdToCdf).toStringAsFixed(2)} USD';
    }
    return '$amountCdf CDF';
  }

  String _hhmm(DateTime d) {
    return '\( {d.hour.toString().padLeft(2, '0')}: \){d.minute.toString().padLeft(2, '0')}';
  }

  String _date(DateTime d) {
    return '\( {d.day.toString().padLeft(2, '0')}/ \){d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
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
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: ThixPolicy.textMain),
          onPressed: () => context.pop(),
        ),
        title: Text(
          '${trip.departureCity} → ${trip.arrivalCity}',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: ThixPolicy.textMain),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_date(trip.departureTime), style: const TextStyle(fontWeight: FontWeight.w700, color: ThixPolicy.textSecondary)),
            const SizedBox(height: 8),
            Text('${trip.agency?.name ?? 'Agence'} • ${trip.busType.toUpperCase()}'),
            const SizedBox(height: 12),
            Text('${_hhmm(trip.departureTime)}  ${trip.departureCity}'),
            Text('${_hhmm(trip.arrivalTime)}  ${trip.arrivalCity}'),
            const SizedBox(height: 8),
            Text('${trip.availableSeats} places • ${trip.durationLabel}'),
            const SizedBox(height: 16),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'CDF', label: Text('CDF')),
                ButtonSegment(value: 'USD', label: Text('USD')),
              ],
              selected: {_fx},
              onSelectionChanged: (s) => setState(() => _fx = s.first),
            ),
            const SizedBox(height: 12),
            Text(_money(trip.priceFcfa), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: ThixPolicy.success)),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: trip.isFull ? null : () => context.push('/thix-reservation/bus/seats', extra: trip),
            style: ElevatedButton.styleFrom(backgroundColor: ThixPolicy.primary, minimumSize: const Size.fromHeight(48)),
            child: Text(
              trip.isFull ? 'Complet' : 'Choisir sièges',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ),
    );
  }
}
