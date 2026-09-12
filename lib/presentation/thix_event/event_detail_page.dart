// lib/presentation/thix_event/event_detail_page.dart
//
// EventDetailPage — Production Enterprise (Sécurité + Sold Out + i18n)
//
// Features :
// - Sanitization XSS complète (titre, desc, org, address)
// - Validation UUID stricte des IDs
// - Throttling anti-spam (500ms) sur toutes les actions
// - Gestion réelle Sold Out via EventSeatService + Queue
// - Intégration AppLocalizations (8 langues)
// - Semantics complet pour a11y
// - Logging structuré (_EventLogger)
// - Design Dark Premium (Fond noir pur, suppression du bleu)
// - Gestion erreurs API robuste (try/catch + feedback UI)
import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/thix_design_policy.dart'; // ThixPolicy
import '../../l10n/app_localizations.dart';
import '../../models/event_model.dart';
import '../../models/ticket_tier.dart';
import '../../providers/event_provider.dart';
import '../../services/event_seat_service.dart';
import 'event_reservation_page.dart';
import 'seat_selection_page.dart';
import 'waiting_queue_page.dart';

// ============================================================================
// THEME LOCAL (Noir Pur pour correspondre aux maquettes)
// ============================================================================
class _ThixColors {
  static const bg = Color(0xFF050508);
  static const surface = Color(0xFF0C0C12);
  static const surfaceAlt = Color(0xFF111118);
  static const cardBorder = Color(0x14FFFFFF);
  static const primary = Color(0xFFFF0A54); // Rose/Rouge
  static const primaryDeep = Color(0xFFFF5E00); // Orange pour le dégradé
  static const textSecondary = Color(0x99FFFFFF);
  static const textMuted = Color(0x66FFFFFF);
  static const warning = Color(0xFFF59E0B);
  static const danger = Color(0xFFEF4444);
}

// ============================================================================
// CONSTANTS & HELPERS
// ============================================================================

const Duration _kActionThrottle = Duration(milliseconds: 500);

// ============================================================================
// LOGGING
// ============================================================================

class _EventLogger {
  static const _tag = 'EventDetail';
  static void info(String m, [Map<String, dynamic>? d]) => _log('INFO', m, d);
  static void warn(String m, [Map<String, dynamic>? d]) => _log('WARN', m, d);
  static void error(String m, [Map<String, dynamic>? d]) => _log('ERROR', m, d);
  
  static void _log(String l, String m, Map<String, dynamic>? d) {
    if (!kDebugMode && l == 'INFO') return;
    final data = d != null
        ? ' ${d.entries.map((e) => '${e.key}=${e.value}').join(', ')}'
        : '';
    debugPrint('[$_tag] [$l] $m$data');
  }
}

// ============================================================================
// SANITIZER (Anti-XSS)
// ============================================================================

class _EventSanitizer {
  _EventSanitizer._();
  
  static String text(String? input, {int maxLength = 5000}) {
    if (input == null) return '';
    var s = input
        .replaceAll(RegExp(r'<[^>]*>'), '') // Remove HTML tags
        .replaceAll(RegExp(r'javascript:', caseSensitive: false), '')
        .replaceAll(RegExp(r'on\w+\s*=', caseSensitive: false), '')
        .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '')
        .trim();
    if (s.length > maxLength) s = s.substring(0, maxLength);
    return s;
  }
}

// ============================================================================
// PAGE
// ============================================================================

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
  DateTime? _lastAction;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _load();
    _EventLogger.info('EventDetailPage init', {'eventId': widget.eventId});
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  bool _throttle() {
    final now = DateTime.now();
    if (_lastAction != null && now.difference(_lastAction!) < _kActionThrottle) {
      return false;
    }
    _lastAction = now;
    return true;
  }

  Future<void> _load() async {
    // Validation UUID
    final uuidRegex = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    if (!uuidRegex.hasMatch(widget.eventId)) {
      _showError('Invalid event ID');
      if (mounted) context.pop();
      return;
    }

    try {
      final svc = ref.read(eventServiceProvider);
      final ev = await svc.getEventById(widget.eventId);
      
      if (!mounted) return;
      
      if (ev == null) {
        _showError('Event not found');
        context.pop();
        return;
      }

      // Sanitization inputs
      final safeEvent = ev.copyWith(
        title: _EventSanitizer.text(ev.title, maxLength: 200),
        description: _EventSanitizer.text(ev.description),
        organizerName: _EventSanitizer.text(ev.organizerName, maxLength: 100),
        location: _EventSanitizer.text(ev.location, maxLength: 200),
        address: _EventSanitizer.text(ev.address, maxLength: 300),
      );

      setState(() { 
        _event = safeEvent; 
        _isLoading = false; 
        _isFavorite = ev.isLiked; 
      });
      
      svc.incrementViews(widget.eventId);
      _loadSeats();
      _EventLogger.info('Event loaded', {'title': safeEvent.title});
    } catch (e, stack) {
      _EventLogger.error('Load failed', {'error': '$e', 'stack': stack.toString()});
      if (!mounted) return;
      _showError('Failed to load event');
      context.pop();
    }
  }

  Future<void> _loadSeats() async {
    try {
      final seats = await EventSeatService(Supabase.instance.client)
          .getSeatMap(widget.eventId)
          .timeout(const Duration(seconds: 10));
      if (!mounted) return;
      setState(() { 
        _hasSeatMap = seats.isNotEmpty; 
        _availableSeats = seats.where((s) => s.isAvailable).length; 
      });
      _EventLogger.info('Seats loaded', {'count': _availableSeats});
    } catch (e) {
      _EventLogger.warn('Seat map load failed', {'error': '$e'});
      // Non-critical: continue without seat map
    }
  }

  Future<void> _toggleFav() async {
    if (!_throttle()) return;
    
    HapticFeedback.lightImpact();
    final svc = ref.read(eventServiceProvider);
    
    setState(() => _isFavorite = !_isFavorite);
    
    try {
      if (_isFavorite) { 
        await svc.likeEvent(widget.eventId);
        _EventLogger.info('Event liked');
      } else { 
        await svc.unlikeEvent(widget.eventId);
        _EventLogger.info('Event unliked');
      }
      ref.invalidate(favoriteEventsProvider);
    } catch (e) {
      _EventLogger.error('Toggle fav failed', {'error': '$e'});
      if (mounted) {
        setState(() => _isFavorite = !_isFavorite); // Rollback
        _showError('Failed to update favorites');
      }
    }
  }

  Future<void> _share() async {
    if (!_throttle()) return;
    
    HapticFeedback.lightImpact();
    final l10n = AppLocalizations.of(context);
    final text = '${_event.title}\n ${_event.formattedDate}\n📍 ${_event.location}\n\n🎟️ ${l10n.t('event_share_cta')}';
    
    try {
      final result = await Share.share(text);
      if (result.status == ShareResultStatus.success) {
        _EventLogger.info('Event shared');
      }
    } catch (e) {
      _EventLogger.warn('Share failed', {'error': '$e'});
      if (mounted) _showError(l10n.t('error_generic'));
    }
  }

  // 🎯 MODIFICATION ICI : Ajout de 'async', 'await' et rafraîchissement au retour
  Future<void> _goReservation({TicketTier? tier}) async {
    if (!_throttle()) return;
    
    HapticFeedback.mediumImpact();
    _EventLogger.info('Go to reservation', {'tier': tier?.name});
    
    await Navigator.push(
      context, 
      MaterialPageRoute(
        builder: (_) => EventReservationPage(
          eventId: _event.id, 
          ticketCategory: tier?.name, 
          ticketPrice: tier?.price
        )
      )
    );

    // Rafraîchir les données quand on revient de la page de réservation
    if (mounted) {
      _load();
      _loadSeats();
    }
  }

  // 🎯 MODIFICATION ICI : Ajout de 'async', 'await' et rafraîchissement au retour
  Future<void> _goSeats() async {
    if (!_throttle()) return;
    
    HapticFeedback.mediumImpact();
    _EventLogger.info('Go to seat selection');
    
    await Navigator.push(
      context, 
      MaterialPageRoute(
        builder: (_) => SeatSelectionPage(eventId: _event.id, event: _event)
      )
    );

    // Rafraîchir les données quand on revient de la page de sélection de sièges
    if (mounted) {
      _load();
      _loadSeats();
    }
  }

  Future<void> _joinQueue() async {
    if (!_throttle()) return;
    
    HapticFeedback.selectionClick();
    setState(() => _isCheckingQueue = true);
    _EventLogger.info('Join queue requested');

    final l10n = AppLocalizations.of(context);
    
    try {
      final showQueue = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: _ThixColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24), 
            side: const BorderSide(color: _ThixColors.cardBorder)
          ),
          title: Text(
            l10n.t('event_sold_out_title'), 
            textAlign: TextAlign.center, 
            style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 18)
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _ThixColors.warning.withOpacity(0.1), 
                  shape: BoxShape.circle
                ),
                child: const Icon(Icons.queue_rounded, size: 42, color: _ThixColors.warning),
              ),
              const SizedBox(height: 20),
              Text(
                l10n.t('event_sold_out_msg'), 
                textAlign: TextAlign.center, 
                style: const TextStyle(color: _ThixColors.textSecondary, height: 1.4, fontSize: 14)
              ),
              const SizedBox(height: 16),
              Text(
                l10n.t('event_join_queue_confirm'), 
                textAlign: TextAlign.center, 
                style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 14)
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                l10n.t('common_cancel'), 
                style: const TextStyle(color: _ThixColors.textMuted, fontWeight: FontWeight.bold)
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: _ThixColors.warning,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                elevation: 0,
              ),
              child: Text(l10n.t('event_join_queue_btn'), style: const TextStyle(fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      );

      setState(() => _isCheckingQueue = false);

      if (showQueue == true && mounted) {
        Navigator.push(
          context, 
          MaterialPageRoute(
            builder: (_) => WaitingQueuePage(
              eventId: _event.id, 
              requestedQuantity: 1
            )
          )
        );
        _EventLogger.info('User joined queue');
      }
    } catch (e) {
      setState(() => _isCheckingQueue = false);
      _EventLogger.error('Queue dialog failed', {'error': '$e'});
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: _ThixColors.danger,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: _ThixColors.bg, 
        body: Center(
          child: CircularProgressIndicator(color: _ThixColors.primary)
        )
      );
    }

    return Scaffold(
      backgroundColor: _ThixColors.bg,
      extendBodyBehindAppBar: true,
      extendBody: true,
      body: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 500,
            pinned: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: Center(
                child: _glassBtn(
                  Icons.arrow_back_rounded, 
                  () => context.pop(),
                  label: l10n.t('common_back')
                )
              ),
            ),
            actions: [
              Semantics(
                button: true,
                label: _isFavorite ? l10n.t('event_unfavorite') : l10n.t('event_favorite'),
                child: _glassBtn(
                  _isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded, 
                  _toggleFav, 
                  isActive: _isFavorite,
                  label: _isFavorite ? l10n.t('event_unfavorite') : l10n.t('event_favorite')
                ),
              ),
              const SizedBox(width: 12),
              Semantics(
                button: true,
                label: l10n.t('common_share'),
                child: _glassBtn(Icons.share_rounded, _share, label: l10n.t('common_share')),
              ),
              const SizedBox(width: 16),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Positioned.fill(
                    child: Container(color: _ThixColors.bg),
                  ),
                  
                  (_event.imageUrl != null && _event.imageUrl!.isNotEmpty)
                      ? Opacity(
                          opacity: 0.85,
                          child: Image.network(
                            _event.imageUrl!, 
                            fit: BoxFit.cover, 
                            errorBuilder: (_, __, ___) => Container(color: _ThixColors.surfaceAlt)
                          )
                        )
                      : Container(
                          color: _ThixColors.surfaceAlt, 
                          child: const Icon(
                            Icons.confirmation_num_rounded, 
                            size: 80, 
                            color: _ThixColors.textMuted
                          )
                        ),
                  
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

                  Positioned(
                    bottom: 24, 
                    left: 20, 
                    right: 20, 
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, 
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6), 
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [_ThixColors.primary, _ThixColors.primaryDeep]
                                ), 
                                borderRadius: BorderRadius.circular(20)
                              ), 
                              child: Text(
                                _event.categoryLabel.toUpperCase(), 
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.5)
                              )
                            ),
                            const SizedBox(width: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6), 
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.15), 
                                    borderRadius: BorderRadius.circular(20), 
                                    border: Border.all(color: Colors.white.withOpacity(0.3))
                                  ), 
                                  child: Text(
                                    _event.isFree ? l10n.t('event_free') : l10n.t('event_paid'), 
                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white)
                                  )
                                ),
                              ),
                            ),
                          ]
                        ),
                        const SizedBox(height: 18),
                        Text(
                          _event.title, 
                          style: const TextStyle(
                            fontSize: 32, 
                            fontWeight: FontWeight.w900, 
                            color: Colors.white, 
                            height: 1.1, 
                            letterSpacing: -1.0
                          )
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(Icons.calendar_month_rounded, size: 16, color: _ThixColors.primary), 
                            const SizedBox(width: 8), 
                            Text(
                              _event.formattedDate, 
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)
                            )
                          ]
                        ),
                      ]
                    )
                  ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 140), 
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, 
                children: [
                  _infoRow(Icons.access_time_filled_rounded, _event.timeRange, l10n.t('event_time_label')),
                  const SizedBox(height: 12),
                  _infoRow(Icons.location_on_rounded, _event.location, l10n.t('event_location_label')),
                  if (_event.address != null && _event.address!.isNotEmpty) ...[
                    const SizedBox(height: 12), 
                    _infoRow(Icons.map_rounded, _event.address!, l10n.t('event_address_label'))
                  ],
                  const SizedBox(height: 32),
                  
                  if ((_event.organizerName ?? '').isNotEmpty) _organizer(l10n),
                  
                  const SizedBox(height: 32),
                  Text(
                    l10n.t('event_about_title'), 
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5)
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity, 
                    padding: const EdgeInsets.all(20), 
                    decoration: BoxDecoration(
                      color: _ThixColors.surface, 
                      borderRadius: BorderRadius.circular(24), 
                      border: Border.all(color: _ThixColors.cardBorder)
                    ), 
                    child: Text(
                      _event.description.isNotEmpty 
                          ? _event.description 
                          : l10n.t('event_no_description'), 
                      style: const TextStyle(fontSize: 14, height: 1.6, color: _ThixColors.textSecondary)
                    )
                  ),
                  const SizedBox(height: 36),
                  
                  Text(
                    l10n.t('event_tickets_title'), 
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5)
                  ),
                  const SizedBox(height: 16),
                  
                  if (_hasSeatMap) 
                    _seatCard(l10n)
                  else if (_event.ticketTiers.isNotEmpty) 
                    ..._event.ticketTiers.map((tier) => _tierCard(l10n, tier))
                  else 
                    _defaultCard(l10n),
                ]
              )
            ),
          ),
        ],
      ),
      bottomNavigationBar: _bottomBar(l10n),
    );
  }

  // 🌟 BOUTONS GLASSMORPHISM
  Widget _glassBtn(IconData icon, VoidCallback onTap, {bool isActive = false, String? label}) {
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center, 
      children: [
        Container(
          height: 48, width: 48,
          decoration: BoxDecoration(
            color: _ThixColors.surface, 
            borderRadius: BorderRadius.circular(16), 
            border: Border.all(color: _ThixColors.cardBorder)
          ), 
          child: Icon(icon, size: 20, color: _ThixColors.textSecondary)
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label, 
                style: const TextStyle(fontSize: 11, color: _ThixColors.textMuted, fontWeight: FontWeight.w600)
              ),
              const SizedBox(height: 2),
              Text(
                text, 
                style: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w800)
              ),
            ],
          ),
        ),
      ]
    );
  }

  Widget _organizer(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(16), 
      decoration: BoxDecoration(
        color: _ThixColors.surface, 
        borderRadius: BorderRadius.circular(20), 
        border: Border.all(color: _ThixColors.cardBorder)
      ), 
      child: Row(
        children: [
          Container(
            height: 50, width: 50, 
            decoration: BoxDecoration(
              color: _ThixColors.surfaceAlt, 
              borderRadius: BorderRadius.circular(16), 
              border: Border.all(color: _ThixColors.cardBorder)
            ), 
            child: const Icon(Icons.business_center_rounded, color: Colors.white)
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, 
              children: [
                Text(
                  l10n.t('event_organized_by'), 
                  style: const TextStyle(color: _ThixColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600)
                ),
                const SizedBox(height: 2),
                Text(
                  _event.organizerName ?? l10n.t('common_unknown'), 
                  style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 15)
                ), 
                if (_event.contactPhone != null && _event.contactPhone!.isNotEmpty) 
                  Text(
                    _event.contactPhone!, 
                    style: const TextStyle(color: _ThixColors.primary, fontSize: 12, fontWeight: FontWeight.w700, height: 1.4)
                  )
              ]
            )
          ),
        ]
      )
    );
  }

  Widget _tierCard(AppLocalizations l10n, TicketTier tier) {
    final int remaining = tier.remaining ?? tier.capacity;
    final bool soldOut = (tier.capacity > 0 && remaining <= 0) || (tier.remaining != null && tier.remaining! <= 0);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16), 
      padding: const EdgeInsets.all(20), 
      decoration: BoxDecoration(
        color: _ThixColors.surface, 
        borderRadius: BorderRadius.circular(24), 
        border: Border.all(
          color: soldOut 
              ? _ThixColors.cardBorder 
              : _ThixColors.primary.withOpacity(0.4)
        ),
        boxShadow: soldOut 
            ? [] 
            : [BoxShadow(color: _ThixColors.primary.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 5))]
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
                      Icon(
                        Icons.confirmation_num_rounded, 
                        size: 18, 
                        color: soldOut ? _ThixColors.textMuted : _ThixColors.primary
                      ), 
                      const SizedBox(width: 8), 
                      Text(
                        tier.name, 
                        style: TextStyle(
                          fontSize: 16, 
                          fontWeight: FontWeight.w900, 
                          color: soldOut ? _ThixColors.textMuted : Colors.white
                        )
                      )
                    ]
                  ),
                  const SizedBox(height: 6),
                  if (tier.capacity > 0)
                    Text(
                      soldOut 
                          ? l10n.t('event_sold_out_short') 
                          : l10n.t('event_remaining_seats', args: [remaining.toString()]), 
                      style: TextStyle(
                        fontSize: 12, 
                        fontWeight: FontWeight.w800, 
                        color: soldOut ? _ThixColors.danger : _ThixColors.primary
                      )
                    ),
                ]
              ),
              Text(
                tier.price == 0 
                    ? l10n.t('event_free') 
                    : '${tier.price.toInt()} ${_event.priceCurrency}', 
                style: TextStyle(
                  fontSize: 20, 
                  fontWeight: FontWeight.w900, 
                  color: soldOut ? _ThixColors.textMuted : Colors.white
                )
              ),
            ]
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity, 
            height: 52, 
            child: ElevatedButton(
              onPressed: soldOut ? _joinQueue : () => _goReservation(tier: tier), 
              style: ElevatedButton.styleFrom(
                backgroundColor: soldOut 
                    ? _ThixColors.warning.withOpacity(0.15) 
                    : Colors.white, 
                foregroundColor: soldOut 
                    ? _ThixColors.warning 
                    : Colors.black, 
                elevation: 0, 
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16), 
                  side: soldOut 
                      ? const BorderSide(color: _ThixColors.warning) 
                      : BorderSide.none
                )
              ), 
              child: Text(
                soldOut 
                    ? l10n.t('event_queue_btn') 
                    : l10n.t('event_book_btn'), 
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5)
              )
            ),
          ),
        ]
      )
    );
  }

  Widget _defaultCard(AppLocalizations l10n) {
    final bool soldOut = (_event.remainingTickets != null && _event.remainingTickets! <= 0);
    
    return Container(
      padding: const EdgeInsets.all(20), 
      decoration: BoxDecoration(
        color: _ThixColors.surface, 
        borderRadius: BorderRadius.circular(24), 
        border: Border.all(
          color: soldOut 
              ? _ThixColors.cardBorder 
              : _ThixColors.primary.withOpacity(0.4)
        ),
        boxShadow: soldOut 
            ? [] 
            : [BoxShadow(color: _ThixColors.primary.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 5))]
      ), 
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween, 
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start, 
                children: [
                  Text(
                    l10n.t('event_standard_entry'), 
                    style: TextStyle(
                      fontWeight: FontWeight.w900, 
                      fontSize: 16, 
                      color: soldOut ? _ThixColors.textMuted : Colors.white
                    )
                  ),
                  const SizedBox(height: 6),
                  if (_event.remainingTickets != null)
                    Text(
                      soldOut 
                          ? l10n.t('event_all_sold') 
                          : l10n.t('event_limited_seats'), 
                      style: TextStyle(
                        fontSize: 12, 
                        fontWeight: FontWeight.w800, 
                        color: soldOut ? _ThixColors.danger : _ThixColors.primary
                      )
                    )
                ]
              ), 
              Text(
                _event.formattedPrice, 
                style: TextStyle(
                  fontWeight: FontWeight.w900, 
                  color: soldOut ? _ThixColors.textMuted : Colors.white, 
                  fontSize: 20
                )
              )
            ]
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity, 
            height: 52, 
            child: ElevatedButton(
              onPressed: soldOut ? _joinQueue : () => _goReservation(), 
              style: ElevatedButton.styleFrom(
                backgroundColor: soldOut 
                    ? _ThixColors.warning.withOpacity(0.15) 
                    : Colors.white, 
                foregroundColor: soldOut 
                    ? _ThixColors.warning 
                    : Colors.black, 
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16), 
                  side: soldOut 
                      ? const BorderSide(color: _ThixColors.warning) 
                      : BorderSide.none
                )
              ), 
              child: Text(
                soldOut 
                    ? l10n.t('event_queue_btn') 
                    : l10n.t('event_book_now_btn'), 
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5)
              )
            ),
          ),
        ]
      )
    );
  }

  Widget _seatCard(AppLocalizations l10n) {
    final soldOut = _availableSeats <= 0;
    return Container(
      padding: const EdgeInsets.all(20), 
      decoration: BoxDecoration(
        color: _ThixColors.surface, 
        borderRadius: BorderRadius.circular(24), 
        border: Border.all(
          color: soldOut 
              ? _ThixColors.cardBorder 
              : _ThixColors.primary.withOpacity(0.4)
        ),
        boxShadow: soldOut 
            ? [] 
            : [BoxShadow(color: _ThixColors.primary.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 5))]
      ), 
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.event_seat_rounded, 
                color: soldOut ? _ThixColors.textMuted : _ThixColors.primary, 
                size: 22
              ), 
              const SizedBox(width: 12), 
              Text(
                soldOut 
                    ? l10n.t('event_sold_out_short') 
                    : l10n.t('event_numbered_seats', args: [_availableSeats.toString()]), 
                style: TextStyle(
                  fontWeight: FontWeight.w900, 
                  fontSize: 16, 
                  color: soldOut ? _ThixColors.textMuted : Colors.white
                )
              )
            ]
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity, 
            height: 52, 
            child: ElevatedButton(
              onPressed: soldOut ? _joinQueue : _goSeats, 
              style: ElevatedButton.styleFrom(
                backgroundColor: soldOut 
                    ? _ThixColors.warning.withOpacity(0.15) 
                    : Colors.white, 
                foregroundColor: soldOut 
                    ? _ThixColors.warning 
                    : Colors.black, 
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16), 
                  side: soldOut 
                      ? const BorderSide(color: _ThixColors.warning) 
                      : BorderSide.none
                )
              ), 
              child: Text(
                soldOut 
                    ? l10n.t('event_queue_btn') 
                    : l10n.t('event_choose_seats_btn'), 
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5)
              )
            ),
          ),
        ]
      )
    );
  }

  // 🌟 BOTTOM BAR FLOTTANTE (Design Noir/Glassmorphism)
  Widget _bottomBar(AppLocalizations l10n) {
    final price = _event.ticketTiers.isNotEmpty 
        ? '${_event.ticketTiers.first.price.toInt()} ${_event.priceCurrency}' 
        : _event.formattedPrice;
        
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
                color: _ThixColors.surface.withOpacity(0.85),
                borderRadius: BorderRadius.circular(36),
                border: Border.all(color: _ThixColors.cardBorder, width: 1.2),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 30, offset: const Offset(0, 10))],
              ),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start, 
                    mainAxisSize: MainAxisSize.min, 
                    children: [
                      Text(
                        l10n.t('event_from_price'), 
                        style: const TextStyle(color: _ThixColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700)
                      ), 
                      const SizedBox(height: 2), 
                      Text(
                        price, 
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)
                      )
                    ]
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => _hasSeatMap ? _goSeats() : _goReservation(), 
                    child: Container(
                      height: 52, 
                      padding: const EdgeInsets.symmetric(horizontal: 28), 
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [_ThixColors.primary, _ThixColors.primaryDeep]
                        ),
                        borderRadius: BorderRadius.circular(26),
                        boxShadow: [BoxShadow(color: _ThixColors.primary.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))]
                      ), 
                      child: Row(
                        children: [
                          Text(
                            l10n.t('event_book_btn'), 
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)
                          ), 
                          const SizedBox(width: 8), 
                          const Icon(Icons.confirmation_num_rounded, size: 18, color: Colors.white)
                        ]
                      )
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
