// lib/presentation/thix_event/event_detail_page.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../providers/event_provider.dart';
import '../../models/event_model.dart';
import '../../models/ticket_tier.dart';
import '../../services/event_seat_service.dart';
import 'event_reservation_page.dart';
import 'seat_selection_page.dart';
import 'waiting_queue_page.dart';

// Design system sombre (Dark Theme)
class _ThixColors {
  static const bg = Color(0xFF050508);
  static const surface = Color(0xFF0C0C12);
  static const surfaceAlt = Color(0xFF111118);
  static const cardBorder = Color(0x14FFFFFF);
  static const primary = Color(0xFFFF0A54);
  static const primaryLight = Color(0xFFFF8FB0);
  static const textSecondary = Color(0x99FFFFFF);
  static const textMuted = Color(0x66FFFFFF);
}

class EventDetailPage extends ConsumerStatefulWidget {
  final String eventId;
  const EventDetailPage({super.key, required this.eventId});
  @override
  ConsumerState<EventDetailPage> createState() => _EventDetailPageState();
}

class _EventDetailPageState extends ConsumerState<EventDetailPage> {
  late Event _event;
  bool _isLoading = true;
  bool _isFavorite = false;
  bool _hasSeatMap = false;
  int _availableSeats = 0;
  bool _isCheckingQueue = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final svc = ref.read(eventServiceProvider);
    final ev = await svc.getEventById(widget.eventId);
    
    if (!mounted) return;
    if (ev == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Événement introuvable')));
      context.pop();
      return;
    }

    setState(() { 
      _event = ev; 
      _isLoading = false; 
      _isFavorite = ev.isLiked; 
    });
    
    svc.incrementViews(widget.eventId);
    _loadSeats();
  }

  Future<void> _loadSeats() async {
    try {
      final seats = await EventSeatService(Supabase.instance.client).getSeatMap(widget.eventId);
      if (!mounted) return;
      setState(() { 
        _hasSeatMap = seats.isNotEmpty; 
        _availableSeats = seats.where((s) => s.isAvailable).length; 
      });
    } catch (_) {}
  }

  Future<void> _toggleFav() async {
    final svc = ref.read(eventServiceProvider);
    setState(() => _isFavorite = !_isFavorite);
    if (_isFavorite) { 
      await svc.likeEvent(widget.eventId); 
    } else { 
      await svc.unlikeEvent(widget.eventId); 
    }
    ref.invalidate(favoriteEventsProvider);
  }

  Future<void> _share() async {
    await Share.share('${_event.title}\n📅 ${_event.formattedDate}\n📍 ${_event.location}\n\nTHIX TICKETS');
  }

  void _goReservation({TicketTier? tier}) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => EventReservationPage(
        eventId: _event.id, 
        ticketCategory: tier?.name, 
        ticketPrice: tier?.price
      )
    ));
  }

  void _goSeats() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => SeatSelectionPage(eventId: _event.id, event: _event)));
  }

  Future<void> _joinQueue() async {
    setState(() => _isCheckingQueue = true);

    final showQueue = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _ThixColors.surface,
        // CORRECTION ICI: Utilisation de `side` et `BorderSide` au lieu de `border`
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16), 
          side: const BorderSide(color: _ThixColors.cardBorder)
        ),
        title: const Text('Catégorie épuisée', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.queue_rounded, size: 48, color: Color(0xFFF59E0B)),
            SizedBox(height: 12),
            Text('Il n\'y a plus de billets disponibles pour cette catégorie.', textAlign: TextAlign.center, style: TextStyle(color: _ThixColors.textSecondary)),
            SizedBox(height: 16),
            Text('Voulez-vous rejoindre la file d\'attente ?', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler', style: TextStyle(color: _ThixColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Rejoindre'),
          ),
        ],
      ),
    );

    setState(() => _isCheckingQueue = false);

    if (showQueue == true && mounted) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => WaitingQueuePage(eventId: _event.id, requestedQuantity: 1)));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(backgroundColor: _ThixColors.bg, body: Center(child: CircularProgressIndicator(color: _ThixColors.primary)));
    }

    return Scaffold(
      backgroundColor: _ThixColors.bg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 460,
            pinned: true,
            backgroundColor: _ThixColors.bg,
            leading: _glassBtn(Icons.arrow_back_rounded, () => context.pop()),
            actions: [
              _glassBtn(_isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded, _toggleFav, isActive: _isFavorite),
              const SizedBox(width: 8),
              _glassBtn(Icons.share_rounded, _share),
              const SizedBox(width: 12),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  (_event.imageUrl != null && _event.imageUrl!.isNotEmpty)
                      ? Image.network(_event.imageUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: _ThixColors.surface))
                      : Container(color: _ThixColors.surfaceAlt, child: const Icon(Icons.event, size: 60, color: _ThixColors.textMuted)),
                  
                  DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black.withOpacity(0.3), Colors.transparent, _ThixColors.bg.withOpacity(0.95)]))),
                  Positioned(bottom: 20, left: 16, right: 16, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5), decoration: BoxDecoration(color: _ThixColors.primary, borderRadius: BorderRadius.circular(20)), child: Text(_event.categoryLabel.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white))),
                      const SizedBox(width: 8),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5), decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.12))), child: Text(_event.isFree ? 'GRATUIT' : 'PAYANT', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white))),
                    ]),
                    const SizedBox(height: 14),
                    Text(_event.title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white, height: 1.05, letterSpacing: -0.5)),
                    const SizedBox(height: 10),
                    Row(children: [const Icon(Icons.calendar_month_rounded, size: 14, color: _ThixColors.textSecondary), const SizedBox(width: 6), Text(_event.formattedDate, style: const TextStyle(color: _ThixColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600))]),
                  ])),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(padding: const EdgeInsets.fromLTRB(16, 20, 16, 120), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _infoRow(Icons.access_time_filled_rounded, _event.timeRange),
              const SizedBox(height: 10),
              _infoRow(Icons.location_on_rounded, _event.location),
              if (_event.address != null && _event.address!.isNotEmpty) ...[const SizedBox(height: 10), _infoRow(Icons.map_rounded, _event.address!)],
              const SizedBox(height: 24),
              
              if ((_event.organizerName ?? '').isNotEmpty) _organizer(),
              
              const SizedBox(height: 24),
              const Text('À propos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
              const SizedBox(height: 12),
              Container(
                width: double.infinity, 
                padding: const EdgeInsets.all(18), 
                decoration: BoxDecoration(color: _ThixColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: _ThixColors.cardBorder)), 
                child: Text(_event.description.isNotEmpty ? _event.description : 'Aucune description disponible pour cet événement.', style: const TextStyle(fontSize: 13, height: 1.6, color: _ThixColors.textSecondary))
              ),
              const SizedBox(height: 28),
              
              const Text('Billets & Réservation', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
              const SizedBox(height: 14),
              
              if (_hasSeatMap) 
                _seatCard()
              else if (_event.ticketTiers.isNotEmpty) 
                ..._event.ticketTiers.map(_tierCard)
              else 
                _defaultCard(),
            ])),
          ),
        ],
      ),
      bottomNavigationBar: _bottomBar(),
    );
  }

  Widget _glassBtn(IconData icon, VoidCallback onTap, {bool isActive = false}) {
    return Padding(padding: const EdgeInsets.only(top: 6), child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(20), child: Container(height: 36, width: 36, decoration: BoxDecoration(color: Colors.black.withOpacity(0.35), shape: BoxShape.circle, border: Border.all(color: Colors.white.withOpacity(0.15))), child: Icon(icon, size: 18, color: isActive ? _ThixColors.primary : Colors.white))));
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: _ThixColors.surfaceAlt, borderRadius: BorderRadius.circular(10), border: Border.all(color: _ThixColors.cardBorder)), child: Icon(icon, size: 14, color: _ThixColors.textSecondary)),
      const SizedBox(width: 10),
      Expanded(child: Padding(padding: const EdgeInsets.only(top: 6), child: Text(text, style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600)))),
    ]);
  }

  Widget _organizer() {
    return Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: _ThixColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: _ThixColors.cardBorder)), child: Row(children: [
      Container(height: 44, width: 44, decoration: BoxDecoration(color: _ThixColors.surfaceAlt, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.business_center_rounded, color: _ThixColors.textSecondary)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_event.organizerName ?? 'Anonyme', style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 13)), 
        if (_event.contactPhone != null && _event.contactPhone!.isNotEmpty) 
          Text(_event.contactPhone!, style: const TextStyle(color: _ThixColors.textMuted, fontSize: 11))
      ])),
    ]));
  }

  Widget _tierCard(TicketTier tier) {
    final int remaining = tier.remaining ?? tier.capacity;
    final bool soldOut = (tier.capacity > 0 && remaining <= 0) || (tier.remaining != null && tier.remaining! <= 0);
    
    return Container(margin: const EdgeInsets.only(bottom: 14), padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: _ThixColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: soldOut ? _ThixColors.cardBorder : _ThixColors.primary.withOpacity(0.3))), child: Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Icon(Icons.confirmation_num_rounded, size: 16, color: soldOut ? _ThixColors.textMuted : _ThixColors.primary), const SizedBox(width: 6), Text(tier.name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: soldOut ? _ThixColors.textMuted : Colors.white))]),
          const SizedBox(height: 6),
          if (tier.capacity > 0)
            Text(soldOut ? 'Épuisé' : '$remaining places restantes', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: soldOut ? Colors.redAccent : _ThixColors.primaryLight)),
        ]),
        Text(tier.price == 0 ? 'Gratuit' : '${tier.price.toInt()} ${_event.priceCurrency}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: soldOut ? _ThixColors.textMuted : Colors.white)),
      ]),
      const SizedBox(height: 16),
      SizedBox(width: double.infinity, height: 44, child: ElevatedButton(onPressed: soldOut ? _joinQueue : () => _goReservation(tier: tier), style: ElevatedButton.styleFrom(backgroundColor: soldOut ? const Color(0x1AF59E0B) : Colors.white, foregroundColor: soldOut ? const Color(0xFFF59E0B) : Colors.black, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: soldOut ? const BorderSide(color: Color(0xFFF59E0B)) : BorderSide.none)), child: Text(soldOut ? 'FILE D\'ATTENTE' : 'RÉSERVER', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)))),
    ]));
  }

  Widget _defaultCard() {
    final bool soldOut = (_event.remainingTickets != null && _event.remainingTickets! <= 0);
    
    return Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: _ThixColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: soldOut ? _ThixColors.cardBorder : _ThixColors.primary.withOpacity(0.3))), child: Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Entrée Standard', style: TextStyle(fontWeight: FontWeight.w800, color: soldOut ? _ThixColors.textMuted : Colors.white)),
          const SizedBox(height: 4),
          if (_event.remainingTickets != null)
            Text(soldOut ? 'Toutes les places sont vendues' : 'Places limitées', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: soldOut ? Colors.redAccent : _ThixColors.primaryLight))
        ]), 
        Text(_event.formattedPrice, style: TextStyle(fontWeight: FontWeight.w900, color: soldOut ? _ThixColors.textMuted : Colors.white, fontSize: 16))
      ]),
      const SizedBox(height: 16),
      SizedBox(width: double.infinity, height: 44, child: ElevatedButton(onPressed: soldOut ? _joinQueue : () => _goReservation(), style: ElevatedButton.styleFrom(backgroundColor: soldOut ? const Color(0x1AF59E0B) : Colors.white, foregroundColor: soldOut ? const Color(0xFFF59E0B) : Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: soldOut ? const BorderSide(color: Color(0xFFF59E0B)) : BorderSide.none)), child: Text(soldOut ? 'FILE D\'ATTENTE' : 'RÉSERVER MAINTENANT', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)))),
    ]));
  }

  Widget _seatCard() {
    final soldOut = _availableSeats <= 0;
    return Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: _ThixColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: soldOut ? _ThixColors.cardBorder : _ThixColors.primary.withOpacity(0.3))), child: Column(children: [
      Row(children: [Icon(Icons.event_seat_rounded, color: soldOut ? _ThixColors.textMuted : _ThixColors.textSecondary, size: 18), const SizedBox(width: 8), Text(soldOut ? 'Complet' : '$_availableSeats places numérotées', style: TextStyle(fontWeight: FontWeight.w700, color: soldOut ? _ThixColors.textMuted : Colors.white))]),
      const SizedBox(height: 16),
      SizedBox(width: double.infinity, height: 44, child: ElevatedButton(onPressed: soldOut ? _joinQueue : _goSeats, style: ElevatedButton.styleFrom(backgroundColor: soldOut ? const Color(0x1AF59E0B) : Colors.white, foregroundColor: soldOut ? const Color(0xFFF59E0B) : Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: soldOut ? const BorderSide(color: Color(0xFFF59E0B)) : BorderSide.none)), child: Text(soldOut ? 'FILE D\'ATTENTE' : 'CHOISIR MES PLACES', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)))),
    ]));
  }

  Widget _bottomBar() {
    final price = _event.ticketTiers.isNotEmpty ? '${_event.ticketTiers.first.price.toInt()} ${_event.priceCurrency}' : _event.formattedPrice;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: const BoxDecoration(color: _ThixColors.surfaceAlt, border: Border(top: BorderSide(color: _ThixColors.cardBorder))),
      child: SafeArea(top: false, child: Row(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [const Text('À partir de', style: TextStyle(color: _ThixColors.textMuted, fontSize: 10, fontWeight: FontWeight.w700)), const SizedBox(height: 2), Text(price, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900))]),
        const Spacer(),
        GestureDetector(onTap: () => _hasSeatMap ? _goSeats() : _goReservation(), child: Container(height: 46, padding: const EdgeInsets.symmetric(horizontal: 26), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(23)), child: const Row(children: [Text('Réserver', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800)), SizedBox(width: 6), Icon(Icons.arrow_outward_rounded, size: 16)]))),
      ])),
    );
  }
}
