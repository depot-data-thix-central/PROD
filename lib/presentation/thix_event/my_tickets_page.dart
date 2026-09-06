// lib/presentation/thix_event/my_tickets_page.dart
//
// MyTicketsPage — Production Enterprise (Design System + i18n + Sécurité)
//
// Features :
// - Alignement complet sur ThixPolicy (Design System centralisé)
// - Intégration AppLocalizations (8 langues)
// - Validation UUID stricte avant navigation
// - Sanitization XSS sur les titres
// - Semantics complet pour a11y
// - Logging structuré (_TicketLogger)
// - Gestion erreurs robuste avec timeout et retry
// - Throttling anti-spam (500ms)
import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/thix_design_policy.dart';
import '../../l10n/app_localizations.dart';
import '../../models/event_booking.dart';
import '../../providers/event_provider.dart';

// ============================================================================
// EVENT THEME ADAPTER (Mappe vers ThixPolicy)
// ============================================================================
// Utilise les tokens officiels de ThixPolicy pour le thème sombre Events.
class EventTheme {
  static const Color bg = ThixPolicy.inkDeep; // 0xFF0A1F44
  static const Color surface = Color(0xFF101B30); // darkSurface
  static const Color surfaceAlt = Color(0xFF14213A); // darkCard
  static const Color border = Color(0xFF243451); // darkBorder
  static const Color primary = ThixPolicy.domainEvents; // 0xFFEF4444
  static const Color accent = ThixPolicy.gold; // 0xFFE3B23C
  static const Color textMain = ThixPolicy.textOnDark;
  static const Color textSecondary = Color(0xFFA8B6CC);
  static const Color textMuted = Color(0xFF64748B);
}

// ============================================================================
// LOGGING
// ============================================================================
class _TicketLogger {
  static const _tag = 'MyTickets';
  static void info(String m, [Map<String, dynamic>? d]) => _log('INFO', m, d);
  static void error(String m, [Map<String, dynamic>? d]) => _log('ERROR', m, d);
  
  static void _log(String l, String m, Map<String, dynamic>? d) {
    if (!kDebugMode && l == 'INFO') return;
    final data = d != null ? ' ${d.entries.map((e) => '${e.key}=${e.value}').join(', ')}' : '';
    debugPrint('[$_tag] [$l] $m$data');
  }
}

// ============================================================================
// VALIDATORS & SANITIZERS
// ============================================================================
class _Validators {
  _Validators._();
  static final _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );
  static bool isValidUuid(String? id) =>
      id != null && id.length == 36 && _uuidRegex.hasMatch(id);
}

class _Sanitizer {
  _Sanitizer._();
  static String text(String? input, {int maxLength = 100}) {
    if (input == null) return '';
    var s = input.replaceAll(RegExp(r'<[^>]*>'), '').trim();
    if (s.length > maxLength) s = s.substring(0, maxLength);
    return s;
  }
}

// ============================================================================
// PAGE
// ============================================================================
class MyTicketsPage extends ConsumerStatefulWidget {
  const MyTicketsPage({super.key});
  
  @override
  ConsumerState<MyTicketsPage> createState() => _MyTicketsPageState();
}

class _MyTicketsPageState extends ConsumerState<MyTicketsPage> {
  List<EventBooking> _tickets = [];
  bool _loading = true;
  bool _error = false;
  DateTime? _lastAction;

  @override
  void initState() {
    super.initState();
    _load();
    _TicketLogger.info('MyTicketsPage initialized');
  }

  bool _throttle() {
    final now = DateTime.now();
    if (_lastAction != null && now.difference(_lastAction!) < const Duration(milliseconds: 500)) {
      return false;
    }
    _lastAction = now;
    return true;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = false;
    });
    
    try {
      final tickets = await ref
          .read(eventServiceProvider)
          .getMyTickets()
          .timeout(const Duration(seconds: 15));
      
      if (!mounted) return;
      
      setState(() {
        _tickets = tickets;
        _loading = false;
      });
      
      _TicketLogger.info('Tickets loaded', {'count': tickets.length});
    } on TimeoutException {
      _TicketLogger.error('Load timeout');
      if (mounted) setState(() { _loading = false; _error = true; });
    } catch (e, stack) {
      _TicketLogger.error('Load failed', {'error': '$e', 'stack': stack.toString()});
      if (mounted) setState(() { _loading = false; _error = true; });
    }
  }

  void _navigateToTicket(String ticketId) {
    if (!_throttle()) {
      _TicketLogger.warn('Navigation throttled');
      return;
    }
    
    if (!_Validators.isValidUuid(ticketId)) {
      _TicketLogger.error('Invalid ticket ID', {'id': ticketId});
      return;
    }
    
    _TicketLogger.info('Navigating to ticket', {'id': ticketId});
    context.push('/thix-event/ticket/$ticketId');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    
    return Scaffold(
      backgroundColor: EventTheme.bg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(52),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: AppBar(
              backgroundColor: EventTheme.bg.withOpacity(0.85),
              elevation: 0,
              leading: Padding(
                padding: const EdgeInsets.all(ThixPolicy.s8),
                child: Semantics(
                  button: true,
                  label: l10n.t('common_back'),
                  child: InkWell(
                    onTap: () => context.go('/thix-event'),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        shape: BoxShape.circle,
                        border: Border.all(color: EventTheme.border),
                      ),
                      child: const Icon(
                        Icons.arrow_back_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ),
              title: Text(
                l10n.t('tickets_my_tickets'),
                style: ThixPolicy.titleStyle.copyWith(
                  color: EventTheme.textMain,
                  fontWeight: FontWeight.w800,
                ),
              ),
              centerTitle: true,
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: EventTheme.primary))
          : _error
              ? _errorState(l10n)
              : _tickets.isEmpty
                  ? _empty(l10n)
                  : RefreshIndicator(
                      color: EventTheme.primary,
                      backgroundColor: EventTheme.surface,
                      onRefresh: _load,
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        padding: const EdgeInsets.fromLTRB(
                          ThixPolicy.s16,
                          ThixPolicy.s16,
                          ThixPolicy.s16,
                          100,
                        ),
                        itemCount: _tickets.length,
                        itemBuilder: (_, i) => _card(l10n, locale, _tickets[i]),
                      ),
                    ),
    );
  }

  Widget _errorState(AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(ThixPolicy.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: EventTheme.textMuted,
            ),
            const SizedBox(height: ThixPolicy.s12),
            Text(
              l10n.t('tickets_load_error'),
              textAlign: TextAlign.center,
              style: ThixPolicy.bodySmallStyle.copyWith(
                color: EventTheme.textSecondary,
              ),
            ),
            const SizedBox(height: ThixPolicy.s18),
            Semantics(
              button: true,
              label: l10n.t('common_retry'),
              child: ElevatedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: Text(l10n.t('common_retry')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(ThixPolicy.rLg),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(AppLocalizations l10n, String locale, EventBooking ticket) {
    final upcoming = DateTime.now().isBefore(ticket.eventDate);
    final safeTitle = _Sanitizer.text(ticket.eventTitle);
    
    // Format date with user's locale
    final dateFormatter = DateFormat('dd MMMM yyyy • HH:mm', locale);
    final formattedDate = dateFormatter.format(ticket.eventDate);
    
    // Use ticket currency or fallback
    final currency = ticket.currency ?? 'FC';
    
    return Semantics(
      button: true,
      label: '${l10n.t('tickets_ticket')}: $safeTitle, $formattedDate',
      child: GestureDetector(
        onTap: () => _navigateToTicket(ticket.id),
        child: Container(
          margin: const EdgeInsets.only(bottom: ThixPolicy.s16),
          decoration: BoxDecoration(
            color: EventTheme.surface,
            borderRadius: BorderRadius.circular(ThixPolicy.rLg),
            border: Border.all(color: EventTheme.border),
            boxShadow: ThixPolicy.shadowCard(opacity: 0.2),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              const Positioned.fill(child: _SecurityWatermark()),
              
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(ThixPolicy.s12),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(ThixPolicy.rSm),
                          child: ticket.eventImageUrl != null &&
                                  ticket.eventImageUrl!.isNotEmpty
                              ? Image.network(
                                  ticket.eventImageUrl!,
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    width: 80,
                                    height: 80,
                                    color: EventTheme.surfaceAlt,
                                    child: Icon(
                                      Icons.confirmation_num_rounded,
                                      color: EventTheme.textMuted,
                                    ),
                                  ),
                                )
                              : Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: EventTheme.primary.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(ThixPolicy.rSm),
                                  ),
                                  child: Icon(
                                    Icons.confirmation_num_rounded,
                                    color: EventTheme.primary,
                                  ),
                                ),
                        ),
                        const SizedBox(width: ThixPolicy.s14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: ThixPolicy.s8,
                                  vertical: ThixPolicy.s4,
                                ),
                                decoration: BoxDecoration(
                                  color: upcoming
                                      ? ThixPolicy.success.withOpacity(0.15)
                                      : Colors.white.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(ThixPolicy.s6),
                                  border: Border.all(
                                    color: upcoming
                                        ? ThixPolicy.success.withOpacity(0.3)
                                        : EventTheme.border,
                                  ),
                                ),
                                child: Text(
                                  upcoming
                                      ? l10n.t('tickets_upcoming')
                                      : l10n.t('tickets_completed'),
                                  style: ThixPolicy.microStyle.copyWith(
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                    color: upcoming
                                        ? ThixPolicy.success
                                        : EventTheme.textMuted,
                                  ),
                                ),
                              ),
                              const SizedBox(height: ThixPolicy.s8),
                              Text(
                                safeTitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: ThixPolicy.bodyMediumStyle.copyWith(
                                  color: EventTheme.textMain,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: ThixPolicy.s6),
                              Text(
                                formattedDate,
                                style: ThixPolicy.captionStyle.copyWith(
                                  color: EventTheme.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          height: 32,
                          width: 32,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            shape: BoxShape.circle,
                            border: Border.all(color: EventTheme.border),
                          ),
                          child: const Icon(
                            Icons.arrow_outward_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: ThixPolicy.s16,
                      vertical: ThixPolicy.s12,
                    ),
                    decoration: BoxDecoration(
                      color: EventTheme.surfaceAlt,
                      border: Border(top: BorderSide(color: EventTheme.border)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.sell_rounded,
                              size: 14,
                              color: EventTheme.accent,
                            ),
                            const SizedBox(width: ThixPolicy.s8),
                            Text(
                              l10n.plural('tickets_quantity', ticket.ticketQuantity),
                              style: ThixPolicy.labelStyle.copyWith(
                                color: EventTheme.textMain,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '${ticket.totalPrice.toStringAsFixed(0)} $currency',
                          style: ThixPolicy.titleStyle.copyWith(
                            color: EventTheme.accent,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _empty(AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(ThixPolicy.s24),
            decoration: BoxDecoration(
              color: EventTheme.surface,
              shape: BoxShape.circle,
              border: Border.all(color: EventTheme.border),
            ),
            child: Icon(
              Icons.local_activity_rounded,
              size: 40,
              color: EventTheme.primary,
            ),
          ),
          const SizedBox(height: ThixPolicy.s20),
          Text(
            l10n.t('tickets_no_tickets'),
            style: ThixPolicy.h2Style.copyWith(
              color: EventTheme.textMain,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: ThixPolicy.s8),
          Text(
            l10n.t('tickets_no_tickets_desc'),
            style: ThixPolicy.bodySmallStyle.copyWith(
              color: EventTheme.textSecondary,
            ),
          ),
          const SizedBox(height: ThixPolicy.s24),
          Semantics(
            button: true,
            label: l10n.t('tickets_discover'),
            child: ElevatedButton(
              onPressed: () {
                if (!_throttle()) return;
                context.go('/thix-event');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(ThixPolicy.r2Xl),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: ThixPolicy.s28,
                  vertical: ThixPolicy.s12,
                ),
              ),
              child: Text(
                l10n.t('tickets_discover'),
                style: ThixPolicy.buttonText.copyWith(
                  color: Colors.black,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// SECURITY WATERMARK (Optimized with ThixPolicy.gold)
// ============================================================================
class _SecurityWatermark extends StatefulWidget {
  const _SecurityWatermark();

  @override
  State<_SecurityWatermark> createState() => _SecurityWatermarkState();
}

class _SecurityWatermarkState extends State<_SecurityWatermark>
    with SingleTickerProviderStateMixin {
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
        return Positioned(
          left: -100 + (_controller.value * 500),
          top: -50,
          bottom: -50,
          width: 80,
          child: Transform.rotate(
            angle: 0.3,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.0),
                    Colors.white.withOpacity(0.03),
                    ThixPolicy.gold.withOpacity(0.04), // Utilise le Gold officiel
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
