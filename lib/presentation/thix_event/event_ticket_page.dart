// lib/presentation/thix_event/event_ticket_page.dart
//
// EventTicketPage — Production Enterprise (Design Premium + Sécurité + i18n)
//
// Features :
// - Design premium : perforations, watermark holographique, glow QR
// - Intégration AppLocalizations (8 langues)
// - ThixPolicy + EventTheme (Design System)
// - Sécurité PIN avec throttling (max 5 tentatives)
// - Sanitization XSS
// - Semantics complet pour a11y
// - Logging structuré
// - Chargement des données 100% sûr (aucune conversion stricte bloquante)
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/thix_design_policy.dart';
import '../../l10n/app_localizations.dart';

// ============================================================================
// EVENT THEME (adapté depuis ThixPolicy pour le thème sombre Events)
// ============================================================================
class EventTheme {
  static const Color bg = ThixPolicy.inkDeep;
  static const Color surface = Color(0xFF101B30);
  static const Color surfaceAlt = Color(0xFF14213A);
  static const Color border = Color(0xFF243451);
  static const Color primary = ThixPolicy.domainEvents;
  static const Color accent = ThixPolicy.gold;
  static const Color textMain = ThixPolicy.textOnDark;
  static const Color textSecondary = Color(0xFFA8B6CC);
  static const Color textMuted = Color(0xFF64748B);
}

// ============================================================================
// LOGGING
// ============================================================================
class _TicketLogger {
  static const _tag = 'EventTicket';
  static void info(String m, [Map<String, dynamic>? d]) => _log('INFO', m, d);
  static void warn(String m, [Map<String, dynamic>? d]) => _log('WARN', m, d);
  static void error(String m, [Map<String, dynamic>? d]) => _log('ERROR', m, d);

  static void _log(String l, String m, Map<String, dynamic>? d) {
    if (!kDebugMode && l == 'INFO') return;
    final data = d != null ? ' ${d.entries.map((e) => '${e.key}=${e.value}').join(', ')}' : '';
    debugPrint('[$_tag] [$l] $m$data');
  }
}

// ============================================================================
// SANITIZER
// ============================================================================
class _Sanitizer {
  _Sanitizer._();
  static String text(String? input, {int maxLength = 200}) {
    if (input == null) return '';
    var s = input.replaceAll(RegExp(r'<[^>]*>'), '').trim();
    if (s.length > maxLength) s = s.substring(0, maxLength);
    return s;
  }
}

// ============================================================================
// PAGE
// ============================================================================
class EventTicketPage extends StatefulWidget {
  final String bookingId;
  const EventTicketPage({super.key, required this.bookingId});

  @override
  State<EventTicketPage> createState() => _EventTicketPageState();
}

class _EventTicketPageState extends State<EventTicketPage>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  bool _qrVisible = false;
  Map<String, dynamic>? _booking;
  Map<String, dynamic>? _event;
  late AnimationController _holo;
  int _pinAttempts = 0;
  static const int _maxPinAttempts = 5;
  DateTime? _lastPinAttempt;

  @override
  void initState() {
    super.initState();
    _holo = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _fetch();
    _TicketLogger.info('EventTicketPage init', {'bookingId': widget.bookingId});
  }

  @override
  void dispose() {
    _holo.dispose();
    _TicketLogger.info('EventTicketPage disposed');
    super.dispose();
  }

  // 🟢 LOGIQUE DE FETCH IDENTIQUE À VOTRE VERSION SIMPLE QUI MARCHE 🟢
  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final res = await Supabase.instance.client
          .from("event_bookings")
          .select("*, events(*)")
          .eq("id", widget.bookingId)
          .single();

      if (mounted) {
        setState(() {
          _booking = res;
          // Si events renvoie une liste, on prend le premier élément, sinon on prend l'objet.
          final rawEvents = res["events"];
          if (rawEvents is List && rawEvents.isNotEmpty) {
            _event = rawEvents.first;
          } else {
            _event = rawEvents;
          }
          _loading = false;
        });
      }
    } catch (e) {
      _TicketLogger.error('Fetch failed', {'error': e.toString()});
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _canAttemptPin() {
    if (_pinAttempts >= _maxPinAttempts) return false;
    final now = DateTime.now();
    if (_lastPinAttempt != null &&
        now.difference(_lastPinAttempt!) < const Duration(seconds: 1)) {
      return false;
    }
    _lastPinAttempt = now;
    return true;
  }

  void _askPin() {
    if (!_canAttemptPin()) {
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.t('ticket_pin_too_many_attempts')),
          backgroundColor: ThixPolicy.danger,
        ),
      );
      return;
    }

    final l10n = AppLocalizations.of(context);
    final ctrl = TextEditingController();
    final correct = _booking?['pin_code']?.toString() ?? '';

    HapticFeedback.mediumImpact();

    showDialog(
      context: context,
      builder: (ctx) => Semantics(
        namesRoute: true,
        scopesRoute: true,
        child: Dialog(
          backgroundColor: EventTheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ThixPolicy.rLg),
            side: const BorderSide(color: EventTheme.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(ThixPolicy.s20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(ThixPolicy.s12),
                  decoration: BoxDecoration(
                    color: EventTheme.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lock_outline_rounded,
                    color: EventTheme.primary,
                    size: 32,
                  ),
                ),
                const SizedBox(height: ThixPolicy.s16),
                Text(
                  l10n.t('ticket_security_title'),
                  style: ThixPolicy.h3Style.copyWith(
                    color: EventTheme.textMain,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: ThixPolicy.s8),
                Text(
                  l10n.t('ticket_enter_pin'),
                  textAlign: TextAlign.center,
                  style: ThixPolicy.bodySmallStyle.copyWith(
                    color: EventTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: ThixPolicy.s16),
                TextField(
                  controller: ctrl,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  textAlign: TextAlign.center,
                  obscureText: true,
                  style: const TextStyle(
                    color: Colors.white,
                    letterSpacing: 8,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '••••',
                    hintStyle: TextStyle(
                      color: EventTheme.textMuted,
                      letterSpacing: 8,
                      fontSize: 24,
                    ),
                    filled: true,
                    fillColor: EventTheme.surfaceAlt,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(ThixPolicy.rSm),
                      borderSide: const BorderSide(color: EventTheme.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(ThixPolicy.rSm),
                      borderSide: const BorderSide(color: EventTheme.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(ThixPolicy.rSm),
                      borderSide: const BorderSide(
                        color: EventTheme.primary,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: ThixPolicy.s8),
                Text(
                  l10n.t('ticket_pin_hint'),
                  style: ThixPolicy.captionStyle.copyWith(
                    color: EventTheme.textMuted,
                  ),
                ),
                const SizedBox(height: ThixPolicy.s20),
                SizedBox(
                  width: double.infinity,
                  height: ThixPolicy.buttonHeight,
                  child: ElevatedButton(
                    onPressed: () {
                      final pin = ctrl.text.trim();
                      if (pin == correct && pin.isNotEmpty) {
                        Navigator.pop(ctx);
                        setState(() => _qrVisible = true);
                        _TicketLogger.info('PIN correct, QR revealed');
                      } else {
                        _pinAttempts++;
                        _TicketLogger.warn('PIN incorrect', {
                          'attempts': _pinAttempts,
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '${l10n.t('ticket_pin_incorrect')} (${_maxPinAttempts - _pinAttempts} ${l10n.t('ticket_attempts_remaining')})',
                            ),
                            backgroundColor: ThixPolicy.danger,
                          ),
                        );
                        if (_pinAttempts >= _maxPinAttempts) {
                          Navigator.pop(ctx);
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: EventTheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(ThixPolicy.rSm),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      l10n.t('ticket_confirm'),
                      style: ThixPolicy.buttonText,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _shareTicket(AppLocalizations l10n) async {
    if (_event == null) return;
    final title = _Sanitizer.text(_event!['title']?.toString());
    final text = '${l10n.t('ticket_share_text')}: $title\n'
        'THIX Tickets\n'
        '${l10n.t('ticket_booking_id')}: ${widget.bookingId}';

    try {
      await Share.share(text);
      _TicketLogger.info('Ticket shared');
    } catch (e) {
      _TicketLogger.warn('Share failed', {'error': '$e'});
    }
  }

  String _formatDate(DateTime dt, String locale) {
    try {
      return DateFormat('dd MMM yyyy • HH:mm', locale).format(dt);
    } catch (_) {
      return DateFormat('dd MMM yyyy • HH:mm', 'fr').format(dt);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;

    if (_loading) {
      return Scaffold(
        backgroundColor: EventTheme.bg,
        body: Center(
          child: CircularProgressIndicator(color: EventTheme.primary),
        ),
      );
    }

    if (_booking == null || _event == null) {
      return Scaffold(
        backgroundColor: EventTheme.bg,
        appBar: _buildAppBar(l10n),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.event_busy_rounded,
                size: 64,
                color: EventTheme.textMuted,
              ),
              const SizedBox(height: ThixPolicy.s16),
              Text(
                l10n.t('ticket_not_found'),
                style: ThixPolicy.h2Style.copyWith(
                  color: EventTheme.textMain,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: ThixPolicy.s24),
              ElevatedButton.icon(
                onPressed: () => context.go('/thix-event'),
                icon: const Icon(Icons.home_rounded, size: 16),
                label: Text(l10n.t('common_home')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(ThixPolicy.rLg),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Parsing sécurisé des champs (comme dans votre version simple)
    final title = _Sanitizer.text(_event!['title']?.toString() ?? 'Événement', maxLength: 100);
    final loc = _Sanitizer.text(_event!['location']?.toString() ?? '', maxLength: 150);
    final dateStr = _event!['date'] ?? _event!['start_date'];
    final dt = dateStr != null
        ? (DateTime.tryParse(dateStr.toString()) ?? DateTime.now())
        : DateTime.now();
    final dateFmt = _formatDate(dt, locale);
    final img = _event!['image_url']?.toString();
    
    final qty = int.tryParse(_booking!['ticket_quantity']?.toString() ?? '1') ?? 1;
    final price = double.tryParse(_booking!['total_price']?.toString() ?? '0') ?? 0.0;
    
    final cat = _Sanitizer.text(
      _booking!['ticket_category']?.toString() ?? l10n.t('ticket_standard'),
    );
    final pin = _booking!['pin_code']?.toString() ?? '****';
    final qr = _booking!['id'].toString();
    final currency = _event!['currency']?.toString() ?? _event!['price_currency']?.toString() ?? '';
    final organizer = _Sanitizer.text(
      _event!['organizer_name']?.toString(),
      maxLength: 60,
    );

    final dash = '-';
    final masked = '****-****-${qr.length >= 4 ? qr.substring(qr.length - 4).toUpperCase() : qr}';
    final shortId = qr.contains(dash) ? qr.split(dash).first.toUpperCase() : qr.toUpperCase();
    final displayId = _qrVisible ? shortId : masked;

    final isUpcoming = dt.isAfter(DateTime.now());
    final isUsed = (_booking!['status']?.toString() ?? '').toLowerCase() == 'used';

    final String formattedPrice = currency.isNotEmpty
        ? (currency == r'$' ? '\$${price.toInt()}' : '${price.toInt()} $currency')
        : '${price.toInt()}';

    return Scaffold(
      backgroundColor: EventTheme.bg,
      appBar: _buildAppBar(l10n),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          children: [
            _buildPremiumTicket(
              l10n: l10n,
              title: title,
              dateFmt: dateFmt,
              loc: loc,
              img: img,
              qty: qty,
              cat: cat,
              pin: pin,
              qr: qr,
              displayId: displayId,
              isUpcoming: isUpcoming,
              isUsed: isUsed,
              formattedPrice: formattedPrice,
              organizer: organizer,
            ),
            const SizedBox(height: ThixPolicy.s20),
            _buildActions(l10n),
            const SizedBox(height: ThixPolicy.s16),
            _buildScanHint(l10n),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(AppLocalizations l10n) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(52),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: AppBar(
            backgroundColor: EventTheme.bg.withOpacity(0.85),
            elevation: 0,
            leading: Semantics(
              button: true,
              label: l10n.t('common_close'),
              child: IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    shape: BoxShape.circle,
                    border: Border.all(color: EventTheme.border),
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
                onPressed: () => context.go('/thix-event'),
              ),
            ),
            title: Text(
              l10n.t('ticket_secure_ticket'),
              style: ThixPolicy.titleStyle.copyWith(
                color: EventTheme.textMain,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
            centerTitle: true,
            actions: [
              Semantics(
                button: true,
                label: l10n.t('ticket_share'),
                child: IconButton(
                  icon: const Icon(Icons.share_rounded, color: Colors.white),
                  onPressed: () => _shareTicket(l10n),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumTicket({
    required AppLocalizations l10n,
    required String title,
    required String dateFmt,
    required String loc,
    required String? img,
    required int qty,
    required String cat,
    required String pin,
    required String qr,
    required String displayId,
    required bool isUpcoming,
    required bool isUsed,
    required String formattedPrice,
    required String organizer,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Perforations latérales (gauche)
        Positioned(
          left: -10,
          top: 220,
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: EventTheme.bg,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 4,
                  offset: const Offset(2, 0),
                ),
              ],
            ),
          ),
        ),
        // Perforations latérales (droite)
        Positioned(
          right: -10,
          top: 220,
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: EventTheme.bg,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 4,
                  offset: const Offset(-2, 0),
                ),
              ],
            ),
          ),
        ),

        // Ticket principal
        Container(
          decoration: BoxDecoration(
            color: EventTheme.surface,
            borderRadius: BorderRadius.circular(ThixPolicy.r2Xl),
            border: Border.all(color: EventTheme.border),
            boxShadow: ThixPolicy.shadowCard(opacity: 0.3),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              // Watermark holographique
              Positioned.fill(child: _HolographicWatermark(controller: _holo)),

              Column(
                children: [
                  // ── IMAGE HEADER ──
                  Stack(
                    children: [
                      if (img != null && img.isNotEmpty)
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(32),
                          ),
                          child: Image.network(
                            img,
                            height: 180,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              height: 180,
                              color: EventTheme.surfaceAlt,
                              child: const Icon(
                                Icons.confirmation_num_rounded,
                                size: 60,
                                color: EventTheme.textMuted,
                              ),
                            ),
                          ),
                        )
                      else
                        Container(
                          height: 180,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                EventTheme.primary.withOpacity(0.3),
                                EventTheme.surfaceAlt,
                              ],
                            ),
                          ),
                          child: const Icon(
                            Icons.confirmation_num_rounded,
                            size: 60,
                            color: EventTheme.textMuted,
                          ),
                        ),

                      // Gradient overlay
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.7),
                              ],
                            ),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(32),
                            ),
                          ),
                        ),
                      ),

                      // Badge statut
                      Positioned(
                        top: 12,
                        left: 12,
                        child: _StatusBadge(
                          isUpcoming: isUpcoming,
                          isUsed: isUsed,
                          l10n: l10n,
                        ),
                      ),

                      // Badge THIX
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: EventTheme.accent.withOpacity(0.5),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.verified_rounded,
                                size: 12,
                                color: EventTheme.accent,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'THIX',
                                style: ThixPolicy.microStyle.copyWith(
                                  color: EventTheme.accent,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Titre sur l'image
                      Positioned(
                        bottom: 12,
                        left: 16,
                        right: 16,
                        child: Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: ThixPolicy.h1Style.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 22,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // ── INFOS ÉVÉNEMENT ──
                  Padding(
                    padding: const EdgeInsets.all(ThixPolicy.s20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _InfoRow(
                          icon: Icons.calendar_today_rounded,
                          label: l10n.t('ticket_date'),
                          value: dateFmt,
                          valueColor: EventTheme.textMain,
                        ),
                        const SizedBox(height: ThixPolicy.s12),
                        _InfoRow(
                          icon: Icons.location_on_rounded,
                          label: l10n.t('ticket_location'),
                          value: loc,
                          valueColor: EventTheme.textSecondary,
                        ),
                        if (organizer.isNotEmpty) ...[
                          const SizedBox(height: ThixPolicy.s12),
                          _InfoRow(
                            icon: Icons.person_outline_rounded,
                            label: l10n.t('ticket_organizer'),
                            value: organizer,
                            valueColor: EventTheme.textSecondary,
                          ),
                        ],
                      ],
                    ),
                  ),

                  // ── LIGNE POINTILLÉE (perforation visuelle) ──
                  CustomPaint(
                    size: const Size(double.infinity, 1),
                    painter: _DashedLinePainter(color: EventTheme.border),
                  ),

                  // ── CATÉGORIE + PRIX + PIN ──
                  Padding(
                    padding: const EdgeInsets.all(ThixPolicy.s16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: EventTheme.primary.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: EventTheme.primary.withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                cat,
                                style: ThixPolicy.labelStyle.copyWith(
                                  color: EventTheme.primary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              l10n.plural('ticket_quantity', qty),
                              style: ThixPolicy.bodySmallStyle.copyWith(
                                color: EventTheme.textSecondary,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              formattedPrice,
                              style: ThixPolicy.titleStyle.copyWith(
                                color: EventTheme.accent,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: ThixPolicy.s12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              l10n.t('ticket_pin_label'),
                              style: ThixPolicy.captionStyle.copyWith(
                                color: EventTheme.textMuted,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: EventTheme.surfaceAlt,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: EventTheme.border),
                              ),
                              child: Text(
                                _qrVisible ? pin : '••••',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 4,
                                  fontFamily: 'monospace',
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // ── QR CODE SECTION ──
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    padding: const EdgeInsets.all(ThixPolicy.s16),
                    decoration: BoxDecoration(
                      color: EventTheme.surfaceAlt,
                      borderRadius: BorderRadius.circular(ThixPolicy.rLg),
                      border: Border.all(
                        color: _qrVisible
                            ? EventTheme.accent.withOpacity(0.4)
                            : EventTheme.border,
                      ),
                      boxShadow: _qrVisible
                          ? [
                              BoxShadow(
                                color: EventTheme.accent.withOpacity(0.15),
                                blurRadius: 20,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      children: [
                        if (_qrVisible)
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 400),
                            child: Container(
                              key: const ValueKey('qr-visible'),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: EventTheme.accent,
                                  width: 2,
                                ),
                              ),
                              child: QrImageView(
                                data: qr,
                                version: QrVersions.auto,
                                size: 180,
                                backgroundColor: Colors.white,
                                eyeStyle: const QrEyeStyle(
                                  eyeShape: QrEyeShape.square,
                                  color: Color(0xFF0A1F44),
                                ),
                                dataModuleStyle: const QrDataModuleStyle(
                                  dataModuleShape: QrDataModuleShape.square,
                                  color: Color(0xFF0A1F44),
                                ),
                              ),
                            ),
                          )
                        else
                          Semantics(
                            button: true,
                            label: l10n.t('ticket_show_qr'),
                            child: GestureDetector(
                              onTap: _askPin,
                              child: Container(
                                key: const ValueKey('qr-hidden'),
                                height: 180,
                                width: 180,
                                decoration: BoxDecoration(
                                  color: EventTheme.surface,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: EventTheme.primary.withOpacity(0.4),
                                    width: 1.5,
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: EventTheme.primary.withOpacity(0.15),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.visibility_rounded,
                                        color: EventTheme.primary,
                                        size: 28,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      l10n.t('ticket_show_qr'),
                                      style: ThixPolicy.labelStyle.copyWith(
                                        color: EventTheme.primary,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: ThixPolicy.s12),
                        Text(
                          '${l10n.t('ticket_booking_id')}: $displayId',
                          style: ThixPolicy.captionStyle.copyWith(
                            color: EventTheme.textMuted,
                            letterSpacing: 1.5,
                            fontFamily: 'monospace',
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
      ],
    );
  }

  Widget _buildActions(AppLocalizations l10n) {
    return Row(
      children: [
        Expanded(
          child: Semantics(
            button: true,
            label: l10n.t('ticket_add_wallet'),
            child: OutlinedButton.icon(
              onPressed: () {
                HapticFeedback.lightImpact();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l10n.t('ticket_wallet_coming_soon')),
                    backgroundColor: EventTheme.primary,
                  ),
                );
              },
              icon: const Icon(Icons.wallet_rounded, size: 16),
              label: Text(l10n.t('ticket_add_wallet')),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: EventTheme.border),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(ThixPolicy.rSm),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Semantics(
            button: true,
            label: l10n.t('ticket_share'),
            child: ElevatedButton.icon(
              onPressed: () => _shareTicket(l10n),
              icon: const Icon(Icons.share_rounded, size: 16),
              label: Text(l10n.t('ticket_share')),
              style: ElevatedButton.styleFrom(
                backgroundColor: EventTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(ThixPolicy.rSm),
                ),
                elevation: 0,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScanHint(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(ThixPolicy.s16),
      decoration: BoxDecoration(
        color: EventTheme.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(ThixPolicy.rSm),
        border: Border.all(
          color: EventTheme.primary.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.qr_code_scanner_rounded,
            color: EventTheme.primary,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l10n.t('ticket_scan_info'),
              style: ThixPolicy.bodySmallStyle.copyWith(
                color: EventTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// WIDGETS AUXILIAIRES
// ============================================================================

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color valueColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 14, color: EventTheme.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: ThixPolicy.captionStyle.copyWith(
                  color: EventTheme.textMuted,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: ThixPolicy.bodyMediumStyle.copyWith(
                  color: valueColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool isUpcoming;
  final bool isUsed;
  final AppLocalizations l10n;

  const _StatusBadge({
    required this.isUpcoming,
    required this.isUsed,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;
    String text;
    IconData icon;

    if (isUsed) {
      bgColor = Colors.grey.withOpacity(0.8);
      textColor = Colors.white;
      text = l10n.t('ticket_status_used');
      icon = Icons.check_circle_rounded;
    } else if (isUpcoming) {
      bgColor = ThixPolicy.success.withOpacity(0.9);
      textColor = Colors.white;
      text = l10n.t('ticket_status_upcoming');
      icon = Icons.schedule_rounded;
    } else {
      bgColor = Colors.black.withOpacity(0.7);
      textColor = Colors.white70;
      text = l10n.t('ticket_status_completed');
      icon = Icons.history_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textColor),
          const SizedBox(width: 4),
          Text(
            text,
            style: ThixPolicy.microStyle.copyWith(
              color: textColor,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  final Color color;
  _DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    const dashWidth = 6;
    const dashSpace = 6;
    double startX = 16;

    while (startX < size.width - 16) {
      canvas.drawLine(
        Offset(startX, 0),
        Offset(startX + dashWidth, 0),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _HolographicWatermark extends StatelessWidget {
  final AnimationController controller;

  const _HolographicWatermark({required this.controller});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, child) {
          return Positioned(
            left: -100 + (controller.value * 500),
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
                      EventTheme.accent.withOpacity(0.05),
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
      ),
    );
  }
}
