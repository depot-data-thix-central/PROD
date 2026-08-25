// lib/presentation/thix_event/event_detail_page.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

// ================= COULEURS SPÉCIFIQUES EVENT (DARK & NEON) =================
class _ThixColors {
  static const bg = Color(0xFF050508); // Noir très profond
  static const surface = Color(0xFF111118);
  static const primary = Color(0xFFFF0A54); // Rose Néon
  static const primaryLight = Color(0xFFFF8FB0);
  static const gradientEnd = Color(0xFFFF8A00); // Orange Néon
  static const accentPurple = Color(0xFF7C3AED); // Violet Néon
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Événement introuvable', style: TextStyle(color: Colors.white))));
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
    HapticFeedback.lightImpact();
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
    HapticFeedback.lightImpact();
    await Share.share('${_event.title}\n📅 ${_event.formattedDate}\n📍 ${_event.location}\n\n🎟️ Réservez sur THIX TICKETS');
  }

  void _goReservation({TicketTier? tier}) {
    HapticFeedback.mediumImpact();
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => EventReservationPage(
        eventId: _event.id, 
        ticketCategory: tier?.name, 
        ticketPrice: tier?.price
      )
    ));
  }

  void _goSeats() {
    HapticFeedback.mediumImpact();
    Navigator.push(context, MaterialPageRoute(builder: (_) => SeatSelectionPage(eventId: _event.id, event: _event)));
  }

  Future<void> _joinQueue() async {
    HapticFeedback.selectionClick();
    setState(() => _isCheckingQueue = true);

    final showQueue = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _ThixColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24), 
          side: BorderSide(color: Colors.white.withOpacity(0.1))
        ),
        title: const Text('Catégorie épuisée', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: const Color(0xFFF59E0B).withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.queue_rounded, size: 42, color: Color(0xFFF59E0B)),
            ),
            const SizedBox(height: 20),
            const Text('Il n\'y a plus de billets disponibles pour cette catégorie.', textAlign: TextAlign.center, style: TextStyle(color: _ThixColors.textSecondary, height: 1.4, fontSize: 14)),
            const SizedBox(height: 16),
            const Text('Voulez-vous rejoindre la file d\'attente prioritaire ?', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 14)),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler', style: TextStyle(color: _ThixColors.textMuted, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              elevation: 0,
            ),
            child: const Text('Rejoindre', style: TextStyle(fontWeight: FontWeight.w900)),
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
      extendBodyBehindAppBar: true,
      extendBody: true,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 500,
            pinned: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: Center(child: _glassBtn(Icons.arrow_back_rounded, () => context.pop())),
            ),
            actions: [
              _glassBtn(_isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded, _toggleFav, isActive: _isFavorite),
              const SizedBox(width: 12),
              _glassBtn(Icons.share_rounded, _share),
              const SizedBox(width: 16),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Lueur radiale de fond pour l'effet Néon
                  Positioned.fill(
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: RadialGradient(
                          colors: [_ThixColors.accentPurple, _ThixColors.bg],
                          radius: 1.5,
                          center: Alignment(0, -0.5),
                        ),
                      ),
                    ),
                  ),
                  
                  // Image de l'Event
                  (_event.imageUrl != null && _event.imageUrl!.isNotEmpty)
                      ? Opacity(
                          opacity: 0.85,
                          child: Image.network(_event.imageUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: _ThixColors.surface))
                        )
                      : Container(color: _ThixColors.surfaceAlt, child: const Icon(Icons.confirmation_num_rounded, size: 80, color: _ThixColors.textMuted)),
                  
                  // Dégradé ultra-doux pour fondre l'image dans le noir
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter, 
                        end: Alignment.bottomCenter, 
                        colors: [
                          _ThixColors.bg.withOpacity(0.4), 
                          Colors.transparent, 
                          _ThixColors.bg.withOpacity(0.9),
                          _ThixColors.bg
                        ],
                        stops: const [0.0, 0.3, 0.8, 1.0],
                      )
                    )
                  ),

                  // Contenu texte par-dessus l'image
                  Positioned(bottom: 24, left: 20, right: 20, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6), 
                        decoration: BoxDecoration(gradient: const LinearGradient(colors: [_ThixColors.primary, _ThixColors.gradientEnd]), borderRadius: BorderRadius.circular(20)), 
                        child: Text(_event.categoryLabel.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.5))
                      ),
                      const SizedBox(width: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6), 
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.3))), 
                            child: Text(_event.isFree ? 'GRATUIT' : 'PAYANT', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white))
                          ),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 18),
                    Text(_event.title, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white, height: 1.1, letterSpacing: -1.0)),
                    const SizedBox(height: 12),
                    Row(children: [const Icon(Icons.calendar_month_rounded, size: 16, color: _ThixColors.primaryLight), const SizedBox(width: 8), Text(_event.formattedDate, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700))]),
                  ])),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(padding: const EdgeInsets.fromLTRB(20, 16, 20, 140), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Informations Clés (Heure, Lieu)
              _infoRow(Icons.access_time_filled_rounded, _event.timeRange, 'Heure'),
              const SizedBox(height: 12),
              _infoRow(Icons.location_on_rounded, _event.location, 'Lieu'),
              if (_event.address != null && _event.address!.isNotEmpty) ...[
                const SizedBox(height: 12), 
                _infoRow(Icons.map_rounded, _event.address!, 'Adresse exacte')
              ],
              const SizedBox(height: 32),
              
              if ((_event.organizerName ?? '').isNotEmpty) _organizer(),
              
              const SizedBox(height: 32),
              const Text('À propos', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5)),
              const SizedBox(height: 16),
              Container(
                width: double.infinity, 
                padding: const EdgeInsets.all(20), 
                decoration: BoxDecoration(color: _ThixColors.surface, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white.withOpacity(0.05))), 
                child: Text(_event.description.isNotEmpty ? _event.description : 'Aucune description disponible pour cet événement.', style: const TextStyle(fontSize: 14, height: 1.6, color: _ThixColors.textSecondary))
              ),
              const SizedBox(height: 36),
              
              const Text('Billets & Réservation', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5)),
              const SizedBox(height: 16),
              
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

  // 🌟 BOUTONS GLASSMORPHISM POUR L'APPBAR
  Widget _glassBtn(IconData icon, VoidCallback onTap, {bool isActive = false}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: InkWell(
          onTap: onTap, 
          child: Container(
            height: 44, width: 44, 
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3), 
              shape: BoxShape.circle, 
              border: Border.all(color: Colors.white.withOpacity(0.2))
            ), 
            child: Icon(icon, size: 20, color: isActive ? _ThixColors.primary : Colors.white)
          )
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text, String label) {
    return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      Container(
        height: 48, width: 48,
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.05))), 
        child: Icon(icon, size: 20, color: _ThixColors.textSecondary)
      ),
      const SizedBox(width: 16),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: _ThixColors.textMuted, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(text, style: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    ]);
  }

  Widget _organizer() {
    return Container(
      padding: const EdgeInsets.all(16), 
      decoration: BoxDecoration(color: _ThixColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.05))), 
      child: Row(children: [
        Container(
          height: 50, width: 50, 
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.1))), 
          child: const Icon(Icons.business_center_rounded, color: Colors.white)
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, 
            children: [
              const Text('Organisé par', style: TextStyle(color: _ThixColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(_event.organizerName ?? 'Anonyme', style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 15)), 
              if (_event.contactPhone != null && _event.contactPhone!.isNotEmpty) 
                Text(_event.contactPhone!, style: const TextStyle(color: _ThixColors.primaryLight, fontSize: 12, fontWeight: FontWeight.w700, height: 1.4))
            ]
          )
        ),
      ])
    );
  }

  Widget _tierCard(TicketTier tier) {
    final int remaining = tier.remaining ?? tier.capacity;
    final bool soldOut = (tier.capacity > 0 && remaining <= 0) || (tier.remaining != null && tier.remaining! <= 0);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16), 
      padding: const EdgeInsets.all(20), 
      decoration: BoxDecoration(
        color: _ThixColors.surface, 
        borderRadius: BorderRadius.circular(24), 
        border: Border.all(color: soldOut ? Colors.white.withOpacity(0.05) : _ThixColors.primary.withOpacity(0.4)),
        boxShadow: soldOut ? [] : [BoxShadow(color: _ThixColors.primary.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 5))]
      ), 
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween, 
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start, 
                children: [
                  Row(
                    children: [
                      Icon(Icons.confirmation_num_rounded, size: 18, color: soldOut ? _ThixColors.textMuted : _ThixColors.primary), 
                      const SizedBox(width: 8), 
                      Text(tier.name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: soldOut ? _ThixColors.textMuted : Colors.white))
                    ]
                  ),
                  const SizedBox(height: 6),
                  if (tier.capacity > 0)
                    Text(soldOut ? 'Épuisé' : '$remaining places restantes', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: soldOut ? Colors.redAccent : _ThixColors.primaryLight)),
                ]
              ),
              Text(tier.price == 0 ? 'Gratuit' : '${tier.price.toInt()} ${_event.priceCurrency}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: soldOut ? _ThixColors.textMuted : Colors.white)),
            ]
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity, 
            height: 52, 
            child: ElevatedButton(
              onPressed: soldOut ? _joinQueue : () => _goReservation(tier: tier), 
              style: ElevatedButton.styleFrom(
                backgroundColor: soldOut ? const Color(0xFFF59E0B).withOpacity(0.15) : Colors.white, 
                foregroundColor: soldOut ? const Color(0xFFF59E0B) : Colors.black, 
                elevation: 0, 
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: soldOut ? const BorderSide(color: Color(0xFFF59E0B)) : BorderSide.none)
              ), 
              child: Text(soldOut ? 'FILE D\'ATTENTE' : 'RÉSERVER', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5))
            )
          ),
        ]
      )
    );
  }

  Widget _defaultCard() {
    final bool soldOut = (_event.remainingTickets != null && _event.remainingTickets! <= 0);
    
    return Container(
      padding: const EdgeInsets.all(20), 
      decoration: BoxDecoration(
        color: _ThixColors.surface, 
        borderRadius: BorderRadius.circular(24), 
        border: Border.all(color: soldOut ? Colors.white.withOpacity(0.05) : _ThixColors.primary.withOpacity(0.4)),
        boxShadow: soldOut ? [] : [BoxShadow(color: _ThixColors.primary.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 5))]
      ), 
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween, 
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start, 
                children: [
                  Text('Entrée Standard', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: soldOut ? _ThixColors.textMuted : Colors.white)),
                  const SizedBox(height: 6),
                  if (_event.remainingTickets != null)
                    Text(soldOut ? 'Toutes les places sont vendues' : 'Places limitées', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: soldOut ? Colors.redAccent : _ThixColors.primaryLight))
                ]
              ), 
              Text(_event.formattedPrice, style: TextStyle(fontWeight: FontWeight.w900, color: soldOut ? _ThixColors.textMuted : Colors.white, fontSize: 20))
            ]
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity, 
            height: 52, 
            child: ElevatedButton(
              onPressed: soldOut ? _joinQueue : () => _goReservation(), 
              style: ElevatedButton.styleFrom(
                backgroundColor: soldOut ? const Color(0xFFF59E0B).withOpacity(0.15) : Colors.white, 
                foregroundColor: soldOut ? const Color(0xFFF59E0B) : Colors.black, 
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: soldOut ? const BorderSide(color: Color(0xFFF59E0B)) : BorderSide.none)
              ), 
              child: Text(soldOut ? 'FILE D\'ATTENTE' : 'RÉSERVER MAINTENANT', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5))
            )
          ),
        ]
      )
    );
  }

  Widget _seatCard() {
    final soldOut = _availableSeats <= 0;
    return Container(
      padding: const EdgeInsets.all(20), 
      decoration: BoxDecoration(
        color: _ThixColors.surface, 
        borderRadius: BorderRadius.circular(24), 
        border: Border.all(color: soldOut ? Colors.white.withOpacity(0.05) : _ThixColors.primary.withOpacity(0.4)),
        boxShadow: soldOut ? [] : [BoxShadow(color: _ThixColors.primary.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 5))]
      ), 
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.event_seat_rounded, color: soldOut ? _ThixColors.textMuted : _ThixColors.primaryLight, size: 22), 
              const SizedBox(width: 12), 
              Text(soldOut ? 'Complet' : '$_availableSeats places numérotées', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: soldOut ? _ThixColors.textMuted : Colors.white))
            ]
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity, 
            height: 52, 
            child: ElevatedButton(
              onPressed: soldOut ? _joinQueue : _goSeats, 
              style: ElevatedButton.styleFrom(
                backgroundColor: soldOut ? const Color(0xFFF59E0B).withOpacity(0.15) : Colors.white, 
                foregroundColor: soldOut ? const Color(0xFFF59E0B) : Colors.black, 
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: soldOut ? const BorderSide(color: Color(0xFFF59E0B)) : BorderSide.none)
              ), 
              child: Text(soldOut ? 'FILE D\'ATTENTE' : 'CHOISIR MES PLACES', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5))
            )
          ),
        ]
      )
    );
  }

  // 🌟 BOTTOM BAR FLOTTANTE EN VERRE DÉPOLI
  Widget _bottomBar() {
    final price = _event.ticketTiers.isNotEmpty ? '${_event.ticketTiers.first.price.toInt()} ${_event.priceCurrency}' : _event.formattedPrice;
    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: SafeArea(
        top: false,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(36),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(36),
                border: Border.all(color: Colors.white.withOpacity(0.15), width: 1.2),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 30, offset: const Offset(0, 10))],
              ),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start, 
                    mainAxisSize: MainAxisSize.min, 
                    children: [
                      const Text('À partir de', style: TextStyle(color: _ThixColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700)), 
                      const SizedBox(height: 2), 
                      Text(price, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900))
                    ]
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => _hasSeatMap ? _goSeats() : _goReservation(), 
                    child: Container(
                      height: 52, 
                      padding: const EdgeInsets.symmetric(horizontal: 28), 
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [_ThixColors.primary, _ThixColors.gradientEnd]),
                        borderRadius: BorderRadius.circular(26),
                        boxShadow: [BoxShadow(color: _ThixColors.primary.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))]
                      ), 
                      child: const Row(
                        children: [
                          Text('Réserver', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)), 
                          SizedBox(width: 8), 
                          Icon(Icons.confirmation_num_rounded, size: 18, color: Colors.white)
                        ]
                      )
                    )
                  ),
                ]
              ),
            ),
          ),
        ),
      ),
    );
  }
}
