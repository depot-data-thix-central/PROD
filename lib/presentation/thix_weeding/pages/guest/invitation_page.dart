// lib/presentation/thix_weeding/pages/guest/invitation_page.dart
// ============================================================================
// THIX WEDDING — PAGE INVITATION GUEST (PRODUCTION v3)
// ✅ 100 % synchronisée en direct : Studio, invité, table, place (realtime)
// ✅ Design rose + verre dépoli (entête glass, photo, carte blanche arrondie)
// ✅ Catégorie, VIP, +1, personnes, table, places, QR code d'entrée
// ✅ Invitation désactivée → accès bloqué (pas de QR)
// ✅ RSVP rapide + calendrier (bouton Partager supprimé)
// ============================================================================
import 'dart:async';
import 'dart:convert';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:thix_id/presentation/thix_weeding/widgets/thix_glass.dart';

class _R {
  static const Color rose = Color(0xFFD81B60);
  static const Color roseDark = Color(0xFFAD1457);
  static const Color roseSoft = Color(0xFFFCE4EC);
  static const Color rosePale = Color(0xFFFFF5F8);
  static const Color gold = Color(0xFFD4AF37);
  static const Color ink = Color(0xFF241521);
  static const Color inkSoft = Color(0xFF8A7580);
  static const Color border = Color(0xFFF3E1E6);
  static const Color green = Color(0xFF059669);
  static const Color amber = Color(0xFFD97706);
  static const Color navy = Color(0xFF0B2E6B);

  static const LinearGradient roseG = LinearGradient(
    colors: [Color(0xFFE91E78), Color(0xFFC2185B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

const Map<String, String> _groupLabels = {
  'famille_marié': 'Famille du marié',
  'famille_mariée': 'Famille de la mariée',
  'amis': 'Amis',
  'collegues': 'Collègues',
  'vip': 'VIP',
};

const Map<String, String> _zoneLabels = {
  'general': 'Zone générale',
  'vip': 'Zone VIP',
  'famille_marié': 'Famille du marié',
  'famille_mariée': 'Famille de la mariée',
  'amis': 'Zone amis',
  'collegues': 'Zone collègues',
};

class InvitationPage extends ConsumerStatefulWidget {
  final String weddingId;

  /// Optionnel : ouvre directement l'invitation d'un invité (lien).
  final String? guestId;

  const InvitationPage({super.key, required this.weddingId, this.guestId});

  @override
  ConsumerState<InvitationPage> createState() => _InvitationPageState();
}

class _InvitationPageState extends ConsumerState<InvitationPage> {
  bool _loading = true;
  String? _error;
  DateTime? _lastSync;

  // Realtime
  RealtimeChannel? _channel;
  Timer? _debounce;
  bool _subscribed = false;

  // Mariage
  String _bride = '';
  String _groom = '';
  DateTime? _date;
  String _venue = '';
  String _uniqueCode = '';
  bool _published = false;

  // invitation_config (Studio)
  String _title = 'Save The Date';
  String _intro = 'Nous avons l\'honneur de vous inviter au mariage de';
  String _outro = 'Venez célébrer cet amour avec nous.';
  String _timeText = '';
  String _placeText = '';
  String _heroUrl = '';
  Color _accent = _R.rose;
  Color _bg = const Color(0xFF1A1520);
  String _templateId = '';

  // Invité
  String? _guestRowId;
  String _guestDisplayName = '';
  String _guestThixId = '';
  String _group = '';
  bool _isVip = false;
  bool _isCompanion = false;
  int? _tableNumber;
  String _tableLabel = '';
  String _tableZone = '';
  List<int> _seats = [];
  bool _invitationActive = true;
  String _deactivatedReason = '';

  // RSVP
  String? _rsvpStatus;
  bool _rsvpSaving = false;
  final _nameCtrl = TextEditingController();
  int _guestsCount = 1;
  int _serverCount = 1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    if (_channel != null) Supabase.instance.client.removeChannel(_channel!);
    _nameCtrl.dispose();
    super.dispose();
  }

  // ───────────────────────── REALTIME ─────────────────────────
  void _scheduleReload() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () {
      if (mounted) _load(silent: true);
    });
  }

  void _subscribe() {
    if (_subscribed) return;
    _subscribed = true;
    final supa = Supabase.instance.client;
    _channel = supa
        .channel('invite-${widget.weddingId}-${_guestRowId ?? 'anon'}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'thix_weeding_weddings',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: widget.weddingId,
          ),
          callback: (_) => _scheduleReload(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'thix_weeding_hall_items',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'wedding_id',
            value: widget.weddingId,
          ),
          callback: (_) => _scheduleReload(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'thix_weeding_guests',
          filter: _guestRowId != null
              ? PostgresChangeFilter(
                  type: PostgresChangeFilterType.eq,
                  column: 'id',
                  value: _guestRowId!,
                )
              : PostgresChangeFilter(
                  type: PostgresChangeFilterType.eq,
                  column: 'wedding_id',
                  value: widget.weddingId,
                ),
          callback: (_) => _scheduleReload(),
        )
        .subscribe();
  }

  // ───────────────────────── CHARGEMENT ─────────────────────────
  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final supa = Supabase.instance.client;
      final row = await supa
          .from('thix_weeding_weddings')
          .select(
              'bride_name, groom_name, wedding_date, venue, unique_code, invitation_published, invitation_config')
          .eq('id', widget.weddingId)
          .maybeSingle();

      if (row == null) {
        if (!mounted) return;
        setState(() {
          _error = 'Invitation introuvable';
          _loading = false;
        });
        return;
      }

      _bride = (row['bride_name'] as String?)?.trim() ?? '';
      _groom = (row['groom_name'] as String?)?.trim() ?? '';
      _venue = (row['venue'] as String?)?.trim() ?? '';
      _uniqueCode = (row['unique_code'] as String?) ?? '';
      _published = (row['invitation_published'] as bool?) ?? false;
      final dateRaw = row['wedding_date'];
      _date = dateRaw != null ? DateTime.tryParse(dateRaw.toString()) : null;

      Map<String, dynamic>? cfg;
      final raw = row['invitation_config'];
      if (raw is Map) {
        cfg = Map<String, dynamic>.from(raw);
      } else if (raw is String && raw.isNotEmpty) {
        try {
          cfg = Map<String, dynamic>.from(jsonDecode(raw) as Map);
        } catch (_) {}
      }

      // Valeurs par défaut (réinitialisées à chaque synchro pour refléter le Studio)
      _title = 'Save The Date';
      _intro = 'Nous avons l\'honneur de vous inviter au mariage de';
      _outro = 'Venez célébrer cet amour avec nous.';
      _timeText = '';
      _heroUrl = '';
      _templateId = '';
      _accent = _R.rose;
      _bg = const Color(0xFF1A1520);
      _placeText = _venue;

      if (cfg != null) {
        Color parseHex(dynamic hex, Color fb) {
          if (hex is! String || hex.isEmpty) return fb;
          try {
            final c = hex.replaceAll('#', '');
            return Color(int.parse('FF$c', radix: 16));
          } catch (_) {
            return fb;
          }
        }

        if ((cfg['title_text'] as String?)?.trim().isNotEmpty == true) {
          _title = cfg['title_text'] as String;
        }
        _intro = (cfg['intro_text'] as String?) ?? _intro;
        _outro = (cfg['outro_text'] as String?) ?? _outro;
        _timeText = (cfg['time_text'] as String?) ?? '';
        if ((cfg['place_text'] as String?)?.trim().isNotEmpty == true) {
          _placeText = cfg['place_text'] as String;
        }
        _heroUrl = (cfg['hero_image_url'] as String?) ?? '';
        _templateId = (cfg['template_id'] as String?) ?? '';
        _accent = parseHex(cfg['primary_color'], _accent);
        _bg = parseHex(cfg['background_color'], _bg);
      }

      // Invité : par lien (guestId) ou par utilisateur connecté
      const cols =
          'id, name, rsvp_status, guests_count, thix_id, table_number, group_name, is_vip, is_companion, hall_table_id, seat_indices, invitation_active, invitation_deactivated_reason';
      Map<String, dynamic>? guest;
      final user = supa.auth.currentUser;
      if (widget.guestId != null) {
        final g = await supa
            .from('thix_weeding_guests')
            .select(cols)
            .eq('id', widget.guestId!)
            .eq('wedding_id', widget.weddingId)
            .maybeSingle();
        guest = g == null ? null : Map<String, dynamic>.from(g);
      } else if (user != null) {
        final g = await supa
            .from('thix_weeding_guests')
            .select(cols)
            .eq('wedding_id', widget.weddingId)
            .eq('user_id', user.id)
            .maybeSingle();
        guest = g == null ? null : Map<String, dynamic>.from(g);
      }

      if (guest != null) {
        _guestRowId = guest['id'] as String?;
        _guestDisplayName = (guest['name'] as String?) ?? '';
        if (_nameCtrl.text.trim().isEmpty) _nameCtrl.text = _guestDisplayName;
        _guestThixId = (guest['thix_id'] as String?) ?? '';
        _rsvpStatus = guest['rsvp_status'] as String?;
        final cnt = (guest['guests_count'] as num?)?.toInt() ?? 1;
        if (!silent || cnt != _serverCount) _guestsCount = cnt;
        _serverCount = cnt;
        _group = (guest['group_name'] as String?) ?? '';
        _isVip = (guest['is_vip'] as bool?) ?? false;
        _isCompanion = (guest['is_companion'] as bool?) ?? false;
        final tn = guest['table_number'];
        _tableNumber = tn is int ? tn : int.tryParse('$tn');
        _invitationActive = (guest['invitation_active'] as bool?) ?? true;
        _deactivatedReason =
            (guest['invitation_deactivated_reason'] as String?) ?? '';
        _seats = ((guest['seat_indices'] as List?) ?? const [])
            .map((e) => (e as num).toInt())
            .toList()
          ..sort();
        _tableLabel = '';
        _tableZone = '';
        final hid = guest['hall_table_id'];
        if (hid != null) {
          final t = await supa
              .from('thix_weeding_hall_items')
              .select('label, table_number, zone')
              .eq('id', hid)
              .maybeSingle();
          _tableLabel = (t?['label'] as String?) ?? '';
          _tableZone = (t?['zone'] as String?) ?? '';
          final tnum = t?['table_number'];
          if (tnum is num) _tableNumber = tnum.toInt();
        }
      }

      _lastSync = DateTime.now();
      if (!mounted) return;
      setState(() => _loading = false);
      _subscribe();
    } catch (e) {
      if (!mounted) return;
      if (silent) return; // on garde l'affichage actuel
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  // ───────────────────────── GETTERS ─────────────────────────
  String get _seatsLabel => _seats.map((e) => e + 1).join(', ');

  String get _tableName =>
      _tableLabel.isNotEmpty ? _tableLabel : (_tableNumber != null ? 'Table $_tableNumber' : '');

  String get _placeSummary {
    if (_tableName.isEmpty) return '';
    return _seats.isEmpty
        ? _tableName
        : '$_tableName · place${_seats.length > 1 ? 's' : ''} $_seatsLabel';
  }

  String get _couple {
    if (_bride.isEmpty && _groom.isEmpty) return 'Les mariés';
    if (_bride.isEmpty) return _groom;
    if (_groom.isEmpty) return _bride;
    return '$_bride & $_groom';
  }

  String get _dateLong {
    if (_date == null) return 'Date à confirmer';
    const months = [
      'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
      'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'
    ];
    const days = ['lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche'];
    final d = _date!;
    final weekday = days[d.weekday - 1];
    return '${weekday[0].toUpperCase()}${weekday.substring(1)} ${d.day} ${months[d.month - 1]} ${d.year}';
  }

  String get _whenLine {
    if (_timeText.trim().isNotEmpty) return '$_dateLong · ${_timeText.trim()}';
    return _dateLong;
  }

  String get _qrData => _guestThixId.isNotEmpty ? _guestThixId : _uniqueCode;

  String get _shownName => _guestDisplayName.isNotEmpty
      ? _guestDisplayName
      : _nameCtrl.text.trim();

  // ───────────────────────── ACTIONS ─────────────────────────
  Future<void> _submitRsvp(String status) async {
    if (!_invitationActive) return;
    final name = _nameCtrl.text.trim();
    if (name.length < 2) {
      _snack('Indiquez votre nom (min. 2 caractères)', _R.rose);
      return;
    }

    setState(() => _rsvpSaving = true);
    HapticFeedback.mediumImpact();

    try {
      final supa = Supabase.instance.client;
      final user = supa.auth.currentUser;
      final payload = <String, dynamic>{
        'wedding_id': widget.weddingId,
        'name': name,
        'rsvp_status': status,
        'guests_count': _guestsCount,
      };
      if (user != null) payload['user_id'] = user.id;

      if (_guestRowId != null) {
        await supa.from('thix_weeding_guests').update({
          'rsvp_status': status,
          'guests_count': _guestsCount,
          'name': name,
        }).eq('id', _guestRowId!);
      } else if (user != null) {
        final existing = await supa
            .from('thix_weeding_guests')
            .select('id')
            .eq('wedding_id', widget.weddingId)
            .eq('user_id', user.id)
            .maybeSingle();
        if (existing != null) {
          await supa.from('thix_weeding_guests').update({
            'rsvp_status': status,
            'guests_count': _guestsCount,
            'name': name,
          }).eq('id', existing['id']);
        } else {
          await supa.from('thix_weeding_guests').insert(payload);
        }
      } else {
        final byName = await supa
            .from('thix_weeding_guests')
            .select('id')
            .eq('wedding_id', widget.weddingId)
            .ilike('name', name)
            .maybeSingle();
        if (byName != null) {
          await supa.from('thix_weeding_guests').update({
            'rsvp_status': status,
            'guests_count': _guestsCount,
          }).eq('id', byName['id']);
        } else {
          await supa.from('thix_weeding_guests').insert(payload);
        }
      }

      if (!mounted) return;
      setState(() {
        _rsvpStatus = status;
        _serverCount = _guestsCount;
        _rsvpSaving = false;
      });

      final label = switch (status) {
        'confirmed' || 'accepted' => 'Présence confirmée ✓',
        'maybe' => 'Réponse « Peut-être » enregistrée',
        'declined' || 'no' => 'Réponse enregistrée — dommage de ne pas vous voir',
        _ => 'Réponse enregistrée',
      };
      _snack(label, status == 'declined' || status == 'no' ? _R.ink : _R.green);
    } catch (e) {
      if (!mounted) return;
      setState(() => _rsvpSaving = false);
      _snack('Erreur RSVP: $e', _R.rose);
    }
  }

  void _snack(String msg, Color bg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: bg,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(14),
      ));
  }

  Future<void> _addToCalendar() async {
    if (_date == null) {
      _snack('Date du mariage non définie', _R.ink);
      return;
    }
    final start = _date!;
    final end = start.add(const Duration(hours: 6));
    String fmt(DateTime d) =>
        '${d.toUtc().year}${d.toUtc().month.toString().padLeft(2, '0')}${d.toUtc().day.toString().padLeft(2, '0')}T'
        '${d.toUtc().hour.toString().padLeft(2, '0')}${d.toUtc().minute.toString().padLeft(2, '0')}00Z';

    final url = Uri.parse(
      'https://calendar.google.com/calendar/render?action=TEMPLATE'
      '&text=${Uri.encodeComponent('Mariage $_couple')}'
      '&dates=${fmt(start)}/${fmt(end)}'
      '&details=${Uri.encodeComponent(_intro)}'
      '&location=${Uri.encodeComponent(_placeText)}',
    );
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {
      _snack('Impossible d\'ouvrir le calendrier', _R.ink);
    }
  }

  // ───────────────────────── BUILD ─────────────────────────
  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final heroH = (mq.size.height * 0.42).clamp(300.0, 430.0).toDouble() + mq.padding.top;

    Widget body;
    if (_loading) {
      body = const Center(child: CircularProgressIndicator(color: _R.rose));
    } else if (_error != null) {
      body = _centerGlass(
        icon: Icons.error_outline,
        iconColor: _R.rose,
        title: _error!,
        action: FilledButton(
          style: FilledButton.styleFrom(backgroundColor: _R.rose),
          onPressed: _load,
          child: const Text('Réessayer'),
        ),
      );
    } else if (!_published) {
      body = _centerGlass(
        icon: Icons.lock_outline,
        iconColor: _R.inkSoft,
        title: 'Cette invitation n\'est pas encore activée',
        subtitle: 'Les organisateurs publieront bientôt le design final.',
      );
    } else if (!_invitationActive) {
      body = _centerGlass(
        icon: Icons.block_rounded,
        iconColor: _R.rose,
        title: 'Invitation désactivée',
        subtitle: _deactivatedReason.isNotEmpty
            ? 'Les organisateurs ont désactivé cette invitation : $_deactivatedReason'
            : 'Les organisateurs ont désactivé cette invitation. Votre QR code n\'est plus valide. Contactez les mariés pour plus d\'informations.',
      );
    } else {
      body = _content(heroH);
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Positioned(top: 0, left: 0, right: 0, height: heroH, child: _hero()),
          Positioned.fill(child: body),
          Positioned(top: 0, left: 0, right: 0, child: _glassHeader(context)),
        ],
      ),
    );
  }

  // ───────────────────────── ENTÊTE GLASS ─────────────────────────
  Widget _glassHeader(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: EdgeInsets.only(top: top),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.38),
            border: Border(
              bottom: BorderSide(color: Colors.white.withOpacity(0.75), width: 1.2),
            ),
          ),
          child: SizedBox(
            height: 74,
            child: Row(
              children: [
                const SizedBox(width: 12),
                if (context.canPop())
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: _R.ink),
                    onPressed: () => context.pop(),
                  )
                else
                  const SizedBox(width: 8),
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: _R.roseG,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _R.rose.withOpacity(0.35),
                        blurRadius: 14,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.favorite, color: Colors.white, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'THIX WEDDING',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.4,
                      color: const Color(0xFF3B3B44).withOpacity(0.6),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ───────────────────────── PHOTO ─────────────────────────
  Widget _hero() {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (_heroUrl.isNotEmpty)
          Image.network(
            _heroUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _heroFallback(),
          )
        else
          _heroFallback(),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withOpacity(0.10),
                Colors.transparent,
                Colors.black.withOpacity(0.18),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _heroFallback() => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.lerp(_bg, _R.rose, 0.35)!,
              Color.lerp(_bg, _R.roseDark, 0.15)!,
            ],
          ),
        ),
        child: Center(
          child: Icon(Icons.favorite, size: 90, color: Colors.white.withOpacity(0.18)),
        ),
      );

  // ───────────────────────── ÉTATS CENTRÉS ─────────────────────────
  Widget _centerGlass({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    Widget? action,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 120, 24, 24),
        child: ThixGlass(
          radius: 28,
          opacity: 0.55,
          padding: const EdgeInsets.all(26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 40, color: iconColor),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 17, color: _R.ink),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 8),
                Text(subtitle,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(color: _R.inkSoft, fontSize: 13, height: 1.4)),
              ],
              if (action != null) ...[const SizedBox(height: 16), action],
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────────────── CONTENU ─────────────────────────
  Widget _content(double heroH) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return RefreshIndicator(
      color: _R.rose,
      edgeOffset: 90,
      onRefresh: () => _load(silent: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: EdgeInsets.zero,
        children: [
          SizedBox(height: heroH - 54),
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.white, _R.rosePale],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 26,
                  offset: const Offset(0, -6),
                ),
              ],
            ),
            padding: EdgeInsets.fromLTRB(18, 28, 18, 40 + bottom),
            child: Column(
              children: [
                _inviteHeader(),
                const SizedBox(height: 18),
                _badges(),
                const SizedBox(height: 18),
                _placeCard(),
                const SizedBox(height: 16),
                _qrCard(),
                const SizedBox(height: 16),
                _detailsCard(),
                const SizedBox(height: 16),
                _rsvpCard(),
                const SizedBox(height: 18),
                _calendarButton(),
                const SizedBox(height: 6),
                TextButton(
                  onPressed: () => context.push('/thix-weeding/guest/${widget.weddingId}/rsvp'),
                  child: Text(
                    'Formulaire RSVP détaillé →',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: _R.rose),
                  ),
                ),
                if (_lastSync != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(color: _R.green, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Mis à jour en direct · ${_lastSync!.hour.toString().padLeft(2, '0')}:${_lastSync!.minute.toString().padLeft(2, '0')}',
                          style: GoogleFonts.inter(fontSize: 10.5, color: _R.inkSoft),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _inviteHeader() {
    final name = _shownName;
    return Column(
      children: [
        Text(
          _title.toUpperCase(),
          textAlign: TextAlign.center,
          style: GoogleFonts.cinzel(
            fontSize: 12,
            letterSpacing: 3,
            fontWeight: FontWeight.w700,
            color: _accent,
          ),
        ),
        if (name.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text('Cher(e)',
              style: GoogleFonts.playfairDisplay(
                  fontSize: 14, fontStyle: FontStyle.italic, color: _R.inkSoft)),
          Text(
            name,
            textAlign: TextAlign.center,
            style: GoogleFonts.playfairDisplay(
                fontSize: 26, fontWeight: FontWeight.w700, color: _R.ink, height: 1.15),
          ),
        ],
        const SizedBox(height: 10),
        Text(
          _intro,
          textAlign: TextAlign.center,
          style: GoogleFonts.cormorantGaramond(
              fontSize: 16, fontStyle: FontStyle.italic, color: _R.inkSoft, height: 1.35),
        ),
        const SizedBox(height: 8),
        Text(
          _couple,
          textAlign: TextAlign.center,
          style: GoogleFonts.greatVibes(fontSize: 42, color: _accent, height: 1.1),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(width: 40, height: 1.4, color: _accent.withOpacity(0.5)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Icon(Icons.favorite, size: 13, color: _accent),
            ),
            Container(width: 40, height: 1.4, color: _accent.withOpacity(0.5)),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          _whenLine.toUpperCase(),
          textAlign: TextAlign.center,
          style: GoogleFonts.cinzel(
              fontSize: 13, letterSpacing: 1.3, fontWeight: FontWeight.w700, color: _accent),
        ),
        if (_placeText.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(_placeText,
              textAlign: TextAlign.center,
              style: GoogleFonts.cormorantGaramond(fontSize: 17, color: _R.ink)),
        ],
        if (_outro.trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            _outro,
            textAlign: TextAlign.center,
            style: GoogleFonts.cormorantGaramond(
                fontSize: 14, fontStyle: FontStyle.italic, color: _accent),
          ),
        ],
      ],
    );
  }

  Widget _badges() {
    final chips = <Widget>[
      if (_isVip) _badge(Icons.star_rounded, 'VIP', _R.gold),
      if (_group.isNotEmpty)
        _badge(Icons.groups_rounded, _groupLabels[_group] ?? _group, _R.rose),
      _badge(Icons.people_alt_rounded,
          '$_guestsCount personne${_guestsCount > 1 ? 's' : ''}', _R.navy),
      if (_isCompanion) _badge(Icons.person_add_alt_1_rounded, 'Accompagnant (+1)', _R.amber),
    ];
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: chips,
    );
  }

  Widget _badge(IconData icon, String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 6),
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 11.5, fontWeight: FontWeight.w800, color: color)),
          ],
        ),
      );

  Widget _placeCard() {
    final has = _tableName.isNotEmpty;
    return ThixGlass(
      radius: 24,
      opacity: 0.55,
      borderColor: _R.rose.withOpacity(0.25),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: _R.roseG,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.event_seat_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('VOTRE PLACE',
                        style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.8,
                            color: _R.inkSoft)),
                    const SizedBox(height: 2),
                    Text(
                      has ? _tableName : 'En cours d\'attribution',
                      style: GoogleFonts.inter(
                          fontSize: 18, fontWeight: FontWeight.w900, color: _R.ink),
                    ),
                    if (_tableZone.isNotEmpty && _tableZone != 'general')
                      Text(_zoneLabels[_tableZone] ?? '',
                          style: GoogleFonts.inter(fontSize: 11, color: _R.inkSoft)),
                  ],
                ),
              ),
            ],
          ),
          if (has && _seats.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _seats
                  .map((s) => Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.8),
                          shape: BoxShape.circle,
                          border: Border.all(color: _R.rose, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: _R.rose.withOpacity(0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Text('${s + 1}',
                            style: GoogleFonts.inter(
                                fontWeight: FontWeight.w900, fontSize: 15, color: _R.rose)),
                      ))
                  .toList(),
            ),
          ] else if (!has)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                'Votre table et votre place apparaîtront ici dès que les mariés les auront choisies.',
                style: GoogleFonts.inter(fontSize: 12, color: _R.inkSoft, height: 1.4),
              ),
            ),
        ],
      ),
    );
  }

  Widget _qrCard() {
    return SizedBox(
      width: double.infinity,
      child: ThixGlass(
        radius: 24,
        opacity: 0.55,
        borderColor: _R.rose.withOpacity(0.2),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('QR code d\'entrée',
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: _R.ink)),
            if (_placeSummary.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: _R.roseSoft,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _placeSummary,
                  style: GoogleFonts.inter(
                      fontSize: 12, fontWeight: FontWeight.w800, color: _R.roseDark),
                ),
              ),
            ],
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _R.border),
                boxShadow: [
                  BoxShadow(
                    color: _R.rose.withOpacity(0.10),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: _qrData.isEmpty
                  ? SizedBox(
                      width: 160,
                      height: 160,
                      child: Center(
                        child: Text('QR indisponible',
                            style: GoogleFonts.inter(color: _R.inkSoft)),
                      ),
                    )
                  : QrImageView(
                      data: _qrData,
                      version: QrVersions.auto,
                      size: 170,
                      backgroundColor: Colors.white,
                      eyeStyle: QrEyeStyle(eyeShape: QrEyeShape.square, color: _accent),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: _R.ink,
                      ),
                    ),
            ),
            const SizedBox(height: 12),
            Text(
              _qrData,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: _R.ink,
              ),
            ),
            const SizedBox(height: 4),
            Text('À présenter à l\'entrée de la salle',
                style: GoogleFonts.inter(fontSize: 11, color: _R.inkSoft)),
          ],
        ),
      ),
    );
  }

  Widget _detailsCard() {
    return _SectionCard(
      title: 'Détails',
      child: Column(
        children: [
          _InfoTile(icon: Icons.calendar_today_rounded, label: 'Date & heure', value: _whenLine),
          const Divider(height: 22, color: _R.border),
          _InfoTile(
            icon: Icons.place_outlined,
            label: 'Lieu',
            value: _placeText.isEmpty ? 'À confirmer' : _placeText,
          ),
          if (_placeSummary.isNotEmpty) ...[
            const Divider(height: 22, color: _R.border),
            _InfoTile(icon: Icons.event_seat_rounded, label: 'Votre place', value: _placeSummary),
          ],
          if (_uniqueCode.isNotEmpty) ...[
            const Divider(height: 22, color: _R.border),
            _InfoTile(
                icon: Icons.qr_code_2_rounded,
                label: 'Code mariage',
                value: _uniqueCode,
                mono: true),
          ],
        ],
      ),
    );
  }

  Widget _rsvpCard() {
    return _SectionCard(
      title: 'Votre réponse (RSVP)',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _nameCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'Votre nom *',
              prefixIcon: const Icon(Icons.person_outline, color: _R.rose),
              filled: true,
              fillColor: Colors.white.withOpacity(0.7),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: _R.rose.withOpacity(0.2)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: _R.rose.withOpacity(0.2)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _R.rose, width: 1.8),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text('Nombre de personnes',
              style: GoogleFonts.inter(
                  fontSize: 12, fontWeight: FontWeight.w700, color: _R.inkSoft)),
          const SizedBox(height: 8),
          Row(
            children: [
              _CountBtn(
                icon: Icons.remove,
                onTap: _guestsCount > 1 ? () => setState(() => _guestsCount--) : null,
              ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 12),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: _R.roseSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$_guestsCount',
                  style: GoogleFonts.inter(
                      fontSize: 18, fontWeight: FontWeight.w900, color: _R.rose),
                ),
              ),
              _CountBtn(
                icon: Icons.add,
                onTap: _guestsCount < 15 ? () => setState(() => _guestsCount++) : null,
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_rsvpStatus != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _statusColor(_rsvpStatus!).withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _statusColor(_rsvpStatus!).withOpacity(0.35)),
              ),
              child: Text(
                'Réponse actuelle : ${_statusLabel(_rsvpStatus!)}',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700, color: _statusColor(_rsvpStatus!)),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: _RsvpBtn(
                  label: 'Confirmé',
                  icon: Icons.check_circle_outline,
                  color: _R.green,
                  selected: _rsvpStatus == 'confirmed' || _rsvpStatus == 'accepted',
                  loading: _rsvpSaving,
                  onTap: () => _submitRsvp('confirmed'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _RsvpBtn(
                  label: 'Peut-être',
                  icon: Icons.help_outline,
                  color: _R.amber,
                  selected: _rsvpStatus == 'maybe',
                  loading: _rsvpSaving,
                  onTap: () => _submitRsvp('maybe'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _RsvpBtn(
                  label: 'Indisponible',
                  icon: Icons.cancel_outlined,
                  color: _R.rose,
                  selected: _rsvpStatus == 'declined' || _rsvpStatus == 'no',
                  loading: _rsvpSaving,
                  onTap: () => _submitRsvp('declined'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _calendarButton() {
    return Container(
      width: double.infinity,
      height: 54,
      decoration: BoxDecoration(
        gradient: _R.roseG,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: _R.rose.withOpacity(0.35),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: _addToCalendar,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.event_available_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Text('Ajouter à mon calendrier',
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w800, fontSize: 15, color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'confirmed':
      case 'accepted':
        return _R.green;
      case 'maybe':
        return _R.amber;
      default:
        return _R.rose;
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'confirmed':
      case 'accepted':
        return 'Confirmé';
      case 'maybe':
        return 'Peut-être';
      case 'declined':
      case 'no':
        return 'Indisponible';
      default:
        return s;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// WIDGETS
// ═══════════════════════════════════════════════════════════════════════════
class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ThixGlass(
        radius: 24,
        opacity: 0.55,
        borderColor: _R.rose.withOpacity(0.18),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 4,
                  height: 18,
                  decoration: BoxDecoration(
                    gradient: _R.roseG,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Text(title,
                    style: GoogleFonts.inter(
                        fontSize: 15, fontWeight: FontWeight.w800, color: _R.ink)),
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool mono;
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.mono = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: _R.roseSoft,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: _R.rose, size: 19),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: GoogleFonts.inter(
                      fontSize: 11, fontWeight: FontWeight.w700, color: _R.inkSoft)),
              const SizedBox(height: 2),
              Text(
                value,
                style: mono
                    ? const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: _R.ink,
                        letterSpacing: 0.8,
                      )
                    : GoogleFonts.inter(
                        fontSize: 14, fontWeight: FontWeight.w600, color: _R.ink, height: 1.35),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RsvpBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final bool loading;
  final VoidCallback onTap;

  const _RsvpBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color : color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: loading ? null : onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? color : color.withOpacity(0.25),
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 20, color: selected ? Colors.white : color),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: selected ? Colors.white : color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CountBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _CountBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: onTap == null ? _R.border : Colors.white,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: _R.rose.withOpacity(0.3)),
          ),
          child: Icon(icon, size: 18, color: onTap == null ? _R.inkSoft : _R.rose),
        ),
      ),
    );
  }
}
