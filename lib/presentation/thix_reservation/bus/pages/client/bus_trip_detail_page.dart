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
      _load();
    }
  }

  Future<void> _load() async {
    final id = widget.tripId ?? widget.trip?.id ?? GoRouterState.of(context).pathParameters['tripId'];
    if (id == null || id.isEmpty) {
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
        if (list.isNotEmpty) row = Map<String, dynamic>.from(list.first);
      } catch (_) {}

      row ??= () {
        return null;
      }();

      if (row == null) {
        final res = await Supabase.instance.client
            .from('bus_trips')
            .select('*, agencies(*)')
            .eq('id', id)
            .limit(1);
        final list = res as List;
        if (list.isNotEmpty) row = Map<String, dynamic>.from(list.first);
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

  String _hhmm(DateTime d) =>
      '\( {d.hour.toString().padLeft(2, '0')}: \){d.minute.toString().padLeft(2, '0')}';

  String _date(DateTime d) =>
      '\( {d.day.toString().padLeft(2, '0')}/ \){d.month.toString().padLeft(2, '0')}/${d.year}';

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
        toolbarHeight: 56,
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
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(ThixPolicy.rLg),
                border: Border.all(color: ThixPolicy.border),
                boxShadow: ThixPolicy.shadowSoft(),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: ThixPolicy.tint,
                    backgroundImage: trip.agency?.logoUrl != null ? NetworkImage(trip.agency!.logoUrl!) : null,
                    child: trip.agency?.logoUrl == null
                        ? Text(
                            trip.agency?.name.isNotEmpty == true ? trip.agency!.name[0] : 'A',
                            style: const TextStyle(fontWeight: FontWeight.w800, color: ThixPolicy.primaryDeep),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                trip.agency?.name ?? 'Agence',
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: ThixPolicy.textMain),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (trip.agency?.isVerified == true) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.verified_rounded, color: ThixPolicy.primary, size: 16),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${trip.busType.toUpperCase()} • \( {trip.agency?.ratingAvg ?? 0} ⭐ ( \){trip.agency?.ratingCount ?? 0} avis)',
                          style: const TextStyle(color: ThixPolicy.textSecondary, fontSize: 11.5, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(ThixPolicy.rLg),
                border: Border.all(color: ThixPolicy.border),
                boxShadow: ThixPolicy.shadowSoft(),
              ),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _date(trip.departureTime),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: ThixPolicy.textSecondary),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_hhmm(trip.departureTime), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
                          const SizedBox(height: 2),
                          Text(trip.departureCity, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                          const SizedBox(height: 2),
                          Text(trip.departureStation, style: const TextStyle(fontSize: 10.5, color: ThixPolicy.textSecondary)),
                        ],
                      ),
                      Column(
                        children: [
                          Text(trip.durationLabel, style: const TextStyle(fontSize: 10.5, color: ThixPolicy.textSecondary, fontWeight: FontWeight.w600)),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 4),
                            child: Icon(Icons.arrow_forward_rounded, size: 16, color: ThixPolicy.primary),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: trip.availableSeats > 0 ? ThixPolicy.success.withOpacity(0.1) : ThixPolicy.danger.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              trip.availableSeats > 0 ? '${trip.availableSeats} places' : 'Complet',
                              style: TextStyle(
                                fontSize: 10,
                                color: trip.availableSeats > 0 ? ThixPolicy.success : ThixPolicy.danger,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(_hhmm(trip.arrivalTime), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
                          const SizedBox(height: 2),
                          Text(trip.arrivalCity, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                          const SizedBox(height: 2),
                          Text(trip.arrivalStation, style: const TextStyle(fontSize: 10.5, color: ThixPolicy.textSecondary)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('Prix affiché', style: TextStyle(fontWeight: FontWeight.w800)),
                const Spacer(),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'CDF', label: Text('CDF')),
                    ButtonSegment(value: 'USD', label: Text('USD')),
                  ],
                  selected: {_fx},
                  onSelectionChanged: (s) => setState(() => _fx = s.first),
                ),
              ],
            ),
            if (trip.amenities.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('Équipements à bord', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: trip.amenities
                    .map((a) => Chip(
                          label: Text(a, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: ThixPolicy.primaryDeep)),
                          backgroundColor: ThixPolicy.tint,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: ThixPolicy.border)),
                        ))
                    .toList(),
              ),
            ],
            const SizedBox(height: 16),
            const Text('Politique agence', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                border: Border.all(color: ThixPolicy.border),
              ),
              child: Text(
                trip.agency?.description ?? 'Aucune politique renseignée par l\'agence.',
                style: const TextStyle(color: ThixPolicy.textSecondary, fontSize: 12.5, height: 1.4),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(top: BorderSide(color: ThixPolicy.border)),
          boxShadow: ThixPolicy.shadowCard(),
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _money(trip.priceFcfa),
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: ThixPolicy.success),
                  ),
                  const Text('par place • frais inclus', style: TextStyle(fontSize: 10.5, color: ThixPolicy.textSecondary)),
                ],
              ),
              const Spacer(),
              SizedBox(
                height: 46,
                child: ElevatedButton(
                  onPressed: trip.isFull
                      ? null
                      : () => context.push('/thix-reservation/bus/seats', extra: trip),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ThixPolicy.primary,
                    disabledBackgroundColor: Colors.grey.shade300,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ThixPolicy.rLg)),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                  ),
                  child: Text(
                    trip.isFull ? 'Complet' : 'Choisir sièges',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
