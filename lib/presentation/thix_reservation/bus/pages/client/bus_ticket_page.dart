// lib/presentation/thix_reservation/bus/pages/client/bus_ticket_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import '../../data/models/booking_model.dart';

class BusTicketPage extends StatefulWidget {
  final BookingModel? booking;
  final String? bookingId;

  const BusTicketPage({
    super.key,
    this.booking,
    this.bookingId,
  });

  @override
  State<BusTicketPage> createState() => _BusTicketPageState();
}

class _BusTicketPageState extends State<BusTicketPage> {
  BookingModel? _booking;
  bool _loading = true;
  String? _error;
  String _fx = 'CDF';
  static const double usdToCdf = 2850;

  String two(int n) {
    final s = n.toString();
    if (s.length == 1) return '0' + s;
    return s;
  }

  String hhmm(DateTime d) {
    return two(d.hour) + ':' + two(d.minute);
  }

  String dmy(DateTime d) {
    return two(d.day) + '/' + two(d.month) + '/' + d.year.toString();
  }

  String money(int amountCdf) {
    if (_fx == 'USD') {
      return (amountCdf / usdToCdf).toStringAsFixed(2) + ' USD';
    }
    return amountCdf.toString() + ' CDF';
  }

  @override
  void initState() {
    super.initState();
    _booking = widget.booking;
    if (_booking != null) {
      _loading = false;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _load();
      });
    }
  }

  Future<void> _load() async {
    String id = widget.bookingId ?? widget.booking?.id ?? '';
    if (id.isEmpty && mounted) {
      id = GoRouterState.of(context).pathParameters['id'] ??
          GoRouterState.of(context).pathParameters['bookingId'] ??
          '';
    }
    if (id.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Billet introuvable';
      });
      return;
    }

    try {
      final res = await Supabase.instance.client
          .from('bus_bookings')
          .select('*, bus_trips(*)')
          .eq('id', id)
          .limit(1);
      final list = res as List;
      if (list.isEmpty) {
        setState(() {
          _loading = false;
          _error = 'Billet introuvable';
        });
        return;
      }
      setState(() {
        _booking = BookingModel.fromJson(Map<String, dynamic>.from(list.first));
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
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null || _booking == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mon billet')),
        body: Center(child: Text(_error ?? 'Billet introuvable')),
      );
    }

    final booking = _booking!;
    final trip = booking.trip;
    final isConfirmed = booking.status == 'confirmed' || booking.status == 'completed';

    return Scaffold(
      backgroundColor: ThixPolicy.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 56,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: ThixPolicy.textMain),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/thix-reservation/bus');
            }
          },
        ),
        title: const Text(
          'Mon billet',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: ThixPolicy.textMain),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_rounded),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: booking.qrCode));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Code copié')),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'CDF', label: Text('CDF')),
                  ButtonSegment(value: 'USD', label: Text('USD')),
                ],
                selected: {_fx},
                onSelectionChanged: (s) => setState(() => _fx = s.first),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(ThixPolicy.rXl),
                border: Border.all(color: ThixPolicy.border),
                boxShadow: ThixPolicy.shadowCard(),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          trip?.agency?.name ?? 'Agence partenaire',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: ThixPolicy.textMain),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isConfirmed
                              ? ThixPolicy.success.withOpacity(0.1)
                              : ThixPolicy.warning.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          booking.status.toUpperCase(),
                          style: TextStyle(
                            color: isConfirmed ? ThixPolicy.success : ThixPolicy.warning,
                            fontWeight: FontWeight.w800,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      trip != null ? dmy(trip.departureTime) : dmy(booking.createdAt),
                      style: const TextStyle(fontSize: 12, color: ThixPolicy.textSecondary, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: ThixPolicy.surface,
                      borderRadius: BorderRadius.circular(ThixPolicy.rLg),
                      border: Border.all(color: ThixPolicy.border),
                    ),
                    child: QrImageView(
                      data: booking.qrCode,
                      size: 180,
                      version: QrVersions.auto,
                      eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: ThixPolicy.textMain),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: ThixPolicy.textMain,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    booking.qrCode,
                    style: const TextStyle(
                      letterSpacing: 2,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: ThixPolicy.textSecondary,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Divider(height: 1, color: ThixPolicy.border),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            trip?.departureCity ?? '-',
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            trip != null ? hhmm(trip.departureTime) : '',
                            style: const TextStyle(fontSize: 12, color: ThixPolicy.textSecondary, fontWeight: FontWeight.w600),
                          ),
                          Text(
                            trip?.departureStation ?? '',
                            style: const TextStyle(fontSize: 10.5, color: ThixPolicy.textSecondary),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(color: ThixPolicy.tint, shape: BoxShape.circle),
                        child: const Icon(Icons.arrow_forward_rounded, size: 16, color: ThixPolicy.primary),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            trip?.arrivalCity ?? '-',
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            trip != null ? hhmm(trip.arrivalTime) : '',
                            style: const TextStyle(fontSize: 12, color: ThixPolicy.textSecondary, fontWeight: FontWeight.w600),
                          ),
                          Text(
                            trip?.arrivalStation ?? '',
                            style: const TextStyle(fontSize: 10.5, color: ThixPolicy.textSecondary),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: ThixPolicy.surface,
                      borderRadius: BorderRadius.circular(ThixPolicy.rMd),
                      border: Border.all(color: ThixPolicy.border),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.event_seat_rounded, size: 16, color: ThixPolicy.primary),
                            const SizedBox(width: 6),
                            Text(
                              'Siege(s) : ' + booking.seats.join(', '),
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                            ),
                          ],
                        ),
                        Text(
                          money(booking.totalPriceFcfa),
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: ThixPolicy.success),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Billet ' + booking.id,
                      style: const TextStyle(fontSize: 10, color: ThixPolicy.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.verified_user_rounded, size: 14, color: ThixPolicy.textSecondary),
                SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Presentez ce QR a l embarquement. Lie a votre THIX ID.',
                    style: TextStyle(color: ThixPolicy.textSecondary, fontSize: 11, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
