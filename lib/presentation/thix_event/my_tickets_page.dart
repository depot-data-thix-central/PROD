// lib/presentation/thix_event/my_tickets_page.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../providers/event_provider.dart';
import '../../models/event_booking.dart';

class _ThixColors {
  static const bg = Color(0xFF050508);
  static const surface = Color(0xFF0C0C12);
  static const surfaceAlt = Color(0xFF111118);
  static const cardBorder = Color(0x14FFFFFF);
  static const primary = Color(0xFFFF0A54);
  static const textSecondary = Color(0x99FFFFFF);
  static const textMuted = Color(0x66FFFFFF);
}

class MyTicketsPage extends ConsumerStatefulWidget {
  const MyTicketsPage({super.key});
  @override
  ConsumerState<MyTicketsPage> createState() => _MyTicketsPageState();
}

class _MyTicketsPageState extends ConsumerState<MyTicketsPage> {
  List<EventBooking> _tickets = [];
  bool _loading = true;

  @override
  void initState() { 
    super.initState(); 
    _load(); 
  }

  Future<void> _load() async {
    try {
      final t = await ref.read(eventServiceProvider).getMyTickets();
      if (mounted) {
        setState(() { 
          _tickets = t; 
          _loading = false; 
        });
      }
    } catch (_) { 
      if (mounted) setState(() => _loading = false); 
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _ThixColors.bg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(52),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: AppBar(
              backgroundColor: _ThixColors.bg.withOpacity(0.85),
              elevation: 0,
              leading: Padding(
                padding: const EdgeInsets.all(8), 
                child: InkWell(
                  onTap: () => context.go('/thix-event'), 
                  child: Container(
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), shape: BoxShape.circle, border: Border.all(color: _ThixColors.cardBorder)), 
                    child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 18)
                  )
                )
              ),
              title: const Text('Mes billets', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
              centerTitle: true,
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _ThixColors.primary))
          : _tickets.isEmpty
              ? _empty()
              : RefreshIndicator(
                  color: _ThixColors.primary,
                  backgroundColor: _ThixColors.surface,
                  onRefresh: () async => _load(),
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    itemCount: _tickets.length,
                    itemBuilder: (_, i) => _card(_tickets[i]),
                  ),
                ),
    );
  }

  Widget _card(EventBooking ticket) {
    final upcoming = DateTime.now().isBefore(ticket.eventDate);
    
    return GestureDetector(
      onTap: () => context.push('/thix-event/ticket/${ticket.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: _ThixColors.surface, 
          borderRadius: BorderRadius.circular(20), 
          border: Border.all(color: _ThixColors.cardBorder),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 5))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // 🟢 FILIGRANE DE SÉCURITÉ ANIMÉ EN ARRIÈRE-PLAN
            const Positioned.fill(
              child: _SecurityWatermark(),
            ),
            
            // CONTENU DU BILLET
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12), 
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12), 
                        child: ticket.eventImageUrl != null && ticket.eventImageUrl!.isNotEmpty
                            ? Image.network(
                                ticket.eventImageUrl!, 
                                width: 80, height: 80, fit: BoxFit.cover, 
                                errorBuilder: (_, __, ___) => Container(width: 80, height: 80, color: _ThixColors.surfaceAlt, child: const Icon(Icons.confirmation_num_rounded, color: _ThixColors.textMuted))
                              ) 
                            : Container(
                                width: 80, height: 80, 
                                decoration: BoxDecoration(color: _ThixColors.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(12)), 
                                child: const Icon(Icons.confirmation_num_rounded, color: _ThixColors.primary)
                              )
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start, 
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), 
                              decoration: BoxDecoration(
                                color: upcoming ? Colors.green.withOpacity(0.15) : Colors.white.withOpacity(0.08), 
                                borderRadius: BorderRadius.circular(6), 
                                border: Border.all(color: upcoming ? Colors.green.withOpacity(0.3) : _ThixColors.cardBorder)
                              ), 
                              child: Text(
                                upcoming ? 'À VENIR' : 'TERMINÉ', 
                                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5, color: upcoming ? Colors.greenAccent : Colors.white54)
                              )
                            ),
                            const SizedBox(height: 8),
                            // 🟢 TEXTE BLANC ET LISIBLE
                            Text(
                              ticket.eventTitle, 
                              maxLines: 2, overflow: TextOverflow.ellipsis, 
                              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900, height: 1.2)
                            ),
                            const SizedBox(height: 6),
                            // 🟢 FORMAT DATE DE L'ANCIENNE VERSION (Blanc cassé)
                            Text(
                              DateFormat('dd MMMM yyyy • HH:mm', 'fr').format(ticket.eventDate), 
                              style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)
                            ),
                          ]
                        )
                      ),
                      Container(
                        height: 32, width: 32, 
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), shape: BoxShape.circle, border: Border.all(color: _ThixColors.cardBorder)), 
                        child: const Icon(Icons.arrow_outward_rounded, size: 14, color: Colors.white)
                      ),
                    ]
                  )
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), 
                  decoration: const BoxDecoration(
                    color: _ThixColors.surfaceAlt, 
                    border: Border(top: BorderSide(color: _ThixColors.cardBorder))
                  ), 
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween, 
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.sell_rounded, size: 14, color: Color(0xFFD4AF37)), 
                          const SizedBox(width: 8), 
                          Text('${ticket.ticketQuantity} billet(s)', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700))
                        ]
                      ),
                      Text('${ticket.totalPrice.toStringAsFixed(0)} FC', style: const TextStyle(color: Color(0xFFD4AF37), fontSize: 14, fontWeight: FontWeight.w900)),
                    ]
                  )
                ),
              ]
            ),
          ],
        ),
      ),
    );
  }

  Widget _empty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min, 
        children: [
          Container(
            padding: const EdgeInsets.all(24), 
            decoration: BoxDecoration(color: _ThixColors.surface, shape: BoxShape.circle, border: Border.all(color: _ThixColors.cardBorder)), 
            child: const Icon(Icons.local_activity_rounded, size: 40, color: _ThixColors.primary)
          ),
          const SizedBox(height: 20),
          const Text('Aucun billet', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
          const SizedBox(height: 8),
          const Text('Vos réservations apparaîtront ici', style: TextStyle(color: Colors.white60, fontSize: 13)),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.go('/thix-event'), 
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white, 
              foregroundColor: Colors.black, 
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)), 
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12)
            ), 
            child: const Text('Découvrir', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13))
          ),
        ]
      )
    );
  }
}

// 🟢 WIDGET ANIMÉ POUR LE FILIGRANE HOLOGRAPHIQUE DE SÉCURITÉ
class _SecurityWatermark extends StatefulWidget {
  const _SecurityWatermark();

  @override
  State<_SecurityWatermark> createState() => _SecurityWatermarkState();
}

class _SecurityWatermarkState extends State<_SecurityWatermark> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // Crée un effet de balayage lumineux et holographique
        return Positioned(
          left: -100 + (_controller.value * 500),
          top: -50,
          bottom: -50,
          width: 80,
          child: Transform.rotate(
            angle: 0.3, // Angle diagonal
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.0),
                    Colors.white.withOpacity(0.03),
                    const Color(0xFFD4AF37).withOpacity(0.04), // Reflet Or/Premium
                    Colors.white.withOpacity(0.03),
                    Colors.white.withOpacity(0.0),
                  ],
                  stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
