// lib/presentation/thix_weeding/pages/guest/invitation_page.dart
// ============================================================================
// THIX WEDDING — PAGE INVITATION GUEST (PRODUCTION)
// ✅ Design Studio (invitation_config) + photo + textes
// ✅ RSVP rapide : Confirmé / Peut-être / Pas disponible
// ✅ Partage + calendrier + navigation RSVP détaillée
// ============================================================================
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:qr_flutter/qr_flutter.dart';

class _R {
  static const Color rose = Color(0xFFE31C4E);
  static const Color roseSoft = Color(0xFFFFE3EA);
  static const Color gold = Color(0xFFD4AF37);
  static const Color ink = Color(0xFF241521);
  static const Color inkSoft = Color(0xFF8A7580);
  static const Color surface = Color(0xFFFFFBFC);
  static const Color border = Color(0xFFF3E1E6);
  static const Color green = Color(0xFF059669);
  static const Color amber = Color(0xFFD97706);
}

class InvitationPage extends ConsumerStatefulWidget {
  final String weddingId;
  const InvitationPage({super.key, required this.weddingId});

  @override
  ConsumerState<InvitationPage> createState() => _InvitationPageState();
}

class _InvitationPageState extends ConsumerState<InvitationPage> {
  bool _loading = true;
  String? _error;

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
  Color _accent = _R.gold;
  Color _bg = const Color(0xFF1A1520);

  // RSVP
  String? _rsvpStatus; // confirmed | maybe | declined
  bool _rsvpSaving = false;
  final _nameCtrl = TextEditingController();
  int _guestsCount = 1;
  String _guestDisplayName = '';
  String _guestThixId = '';
  int? _tableNumber;
  String _templateId = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final row = await Supabase.instance.client
          .from('thix_weeding_weddings')
          .select(
              'bride_name, groom_name, wedding_date, venue, unique_code, invitation_published, invitation_config')
          .eq('id', widget.weddingId)
          .maybeSingle();

      if (row == null) {
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
      if (dateRaw != null) {
        _date = DateTime.tryParse(dateRaw.toString());
      }

      Map<String, dynamic>? cfg;
      final raw = row['invitation_config'];
      if (raw is Map) {
        cfg = Map<String, dynamic>.from(raw);
      } else if (raw is String && raw.isNotEmpty) {
        try {
          cfg = Map<String, dynamic>.from(jsonDecode(raw) as Map);
        } catch (_) {}
      }

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

        _title = (cfg['title_text'] as String?)?.trim().isNotEmpty == true
            ? cfg['title_text'] as String
            : _title;
        _intro = (cfg['intro_text'] as String?) ?? _intro;
        _outro = (cfg['outro_text'] as String?) ?? _outro;
        _timeText = (cfg['time_text'] as String?) ?? '';
        _placeText = (cfg['place_text'] as String?)?.trim().isNotEmpty == true
            ? cfg['place_text'] as String
            : _venue;
        _heroUrl = (cfg['hero_image_url'] as String?) ?? '';
        _templateId = (cfg['template_id'] as String?) ?? '';
        _accent = parseHex(cfg['primary_color'], _accent);
        _bg = parseHex(cfg['background_color'], _bg);
      } else {
        _placeText = _venue;
      }

      // Pré-remplir nom si utilisateur connecté + guest lié
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final guest = await Supabase.instance.client
            .from('thix_weeding_guests')
            .select('id, name, rsvp_status, guests_count, thix_id, table_number')
            .eq('wedding_id', widget.weddingId)
            .eq('user_id', user.id)
            .maybeSingle();
        if (guest != null) {
          _nameCtrl.text = (guest['name'] as String?) ?? '';
          _guestDisplayName = (guest['name'] as String?) ?? '';
          _guestThixId = (guest['thix_id'] as String?) ?? '';
          _rsvpStatus = guest['rsvp_status'] as String?;
          _guestsCount = (guest['guests_count'] as int?) ?? 1;
          final tn = guest['table_number'];
          _tableNumber = tn is int ? tn : int.tryParse('$tn');
        }
      }

      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
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
    const days = [
      'lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche'
    ];
    final d = _date!;
    final weekday = days[d.weekday - 1];
    return '${weekday[0].toUpperCase()}${weekday.substring(1)} ${d.day} ${months[d.month - 1]} ${d.year}';
  }

  String get _whenLine {
    if (_timeText.trim().isNotEmpty) return '$_dateLong · ${_timeText.trim()}';
    return _dateLong;
  }

  Future<void> _submitRsvp(String status) async {
    final name = _nameCtrl.text.trim();
    if (name.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Indiquez votre nom (min. 2 caractères)'),
        backgroundColor: _R.rose,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    setState(() => _rsvpSaving = true);
    HapticFeedback.mediumImpact();

    try {
      final user = Supabase.instance.client.auth.currentUser;
      final payload = <String, dynamic>{
        'wedding_id': widget.weddingId,
        'name': name,
        'rsvp_status': status,
        'guests_count': _guestsCount,
      };
      if (user != null) payload['user_id'] = user.id;

      // Upsert : si guest lié existe → update, sinon insert
      if (user != null) {
        final existing = await Supabase.instance.client
            .from('thix_weeding_guests')
            .select('id')
            .eq('wedding_id', widget.weddingId)
            .eq('user_id', user.id)
            .maybeSingle();

        if (existing != null) {
          await Supabase.instance.client
              .from('thix_weeding_guests')
              .update({
                'rsvp_status': status,
                'guests_count': _guestsCount,
                'name': name,
              })
              .eq('id', existing['id']);
        } else {
          await Supabase.instance.client
              .from('thix_weeding_guests')
              .insert(payload);
        }
      } else {
        // Invité anonyme : insert simple (ou update par nom si déjà présent)
        final byName = await Supabase.instance.client
            .from('thix_weeding_guests')
            .select('id')
            .eq('wedding_id', widget.weddingId)
            .ilike('name', name)
            .maybeSingle();
        if (byName != null) {
          await Supabase.instance.client.from('thix_weeding_guests').update({
            'rsvp_status': status,
            'guests_count': _guestsCount,
          }).eq('id', byName['id']);
        } else {
          await Supabase.instance.client
              .from('thix_weeding_guests')
              .insert(payload);
        }
      }

      if (!mounted) return;
      setState(() {
        _rsvpStatus = status;
        _rsvpSaving = false;
      });

      final label = switch (status) {
        'confirmed' || 'accepted' => 'Présence confirmée ✓',
        'maybe' => 'Réponse « Peut-être » enregistrée',
        'declined' || 'no' => 'Réponse enregistrée — dommage de ne pas vous voir',
        _ => 'Réponse enregistrée',
      };

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: status == 'declined' || status == 'no' ? _R.ink : _R.green,
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _rsvpSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Erreur RSVP: $e'),
        backgroundColor: _R.rose,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _share() async {
    final text = 'Invitation — $_couple\n$_whenLine'
        '${_placeText.isNotEmpty ? '\n$_placeText' : ''}'
        '${_uniqueCode.isNotEmpty ? '\nCode: $_uniqueCode' : ''}'
        '\nhttps://thix.id';
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Invitation copiée — collez-la pour partager'),
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _addToCalendar() async {
    if (_date == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Date du mariage non définie'),
        behavior: SnackBarBehavior.floating,
      ));
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Impossible d\'ouvrir le calendrier'),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _R.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: _R.ink,
        title: Text(
          'Invitation',
          style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () {
            if (context.canPop()) context.pop();
          },
        ),
        actions: [
          IconButton(
            tooltip: 'Partager',
            onPressed: _loading ? null : _share,
            icon: const Icon(Icons.share_outlined, size: 20),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _R.rose))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, size: 40, color: _R.rose),
                        const SizedBox(height: 12),
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton(onPressed: _load, child: const Text('Réessayer')),
                      ],
                    ),
                  ),
                )
              : !_published
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.lock_outline, size: 48, color: _R.inkSoft),
                            const SizedBox(height: 12),
                            Text(
                              'Cette invitation n\'est pas encore activée',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                color: _R.ink,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Les organisateurs publieront bientôt le design final.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(color: _R.inkSoft, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      color: _R.rose,
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                        children: [
                          // ── Carte invitation (design Studio) ─────────────
                          _StudioInviteCard(
                            title: _title,
                            intro: _intro,
                            outro: _outro,
                            couple: _couple,
                            whenLine: _whenLine,
                            place: _placeText,
                            heroUrl: _heroUrl,
                            accent: _accent,
                            bg: _bg,
                            uniqueCode: _uniqueCode,
                            guestName: _guestDisplayName.isNotEmpty
                                ? _guestDisplayName
                                : (_nameCtrl.text.trim().isNotEmpty
                                    ? _nameCtrl.text.trim()
                                    : null),
                            guestAccessCode: _guestThixId.isNotEmpty
                                ? _guestThixId
                                : _uniqueCode,
                            tableNumber: _tableNumber,
                            templateId: _templateId,
                          ),
                          const SizedBox(height: 20),

                          // ── Infos ───────────────────────────────────────
                          _SectionCard(
                            title: 'Détails',
                            child: Column(
                              children: [
                                _InfoTile(
                                  icon: Icons.calendar_today_rounded,
                                  label: 'Date & heure',
                                  value: _whenLine,
                                ),
                                const Divider(height: 20),
                                _InfoTile(
                                  icon: Icons.place_outlined,
                                  label: 'Lieu',
                                  value: _placeText.isEmpty ? 'À confirmer' : _placeText,
                                ),
                                if (_uniqueCode.isNotEmpty) ...[
                                  const Divider(height: 20),
                                  _InfoTile(
                                    icon: Icons.qr_code_2_rounded,
                                    label: 'Code mariage',
                                    value: _uniqueCode,
                                    mono: true,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // ── RSVP ────────────────────────────────────────
                          _SectionCard(
                            title: 'Votre réponse (RSVP)',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TextField(
                                  controller: _nameCtrl,
                                  textCapitalization: TextCapitalization.words,
                                  decoration: InputDecoration(
                                    labelText: 'Votre nom *',
                                    prefixIcon: const Icon(Icons.person_outline),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  'Nombre de personnes',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: _R.inkSoft,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    _CountBtn(
                                      icon: Icons.remove,
                                      onTap: _guestsCount > 1
                                          ? () => setState(() => _guestsCount--)
                                          : null,
                                    ),
                                    Container(
                                      margin: const EdgeInsets.symmetric(horizontal: 12),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 18, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: _R.roseSoft,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '$_guestsCount',
                                        style: GoogleFonts.inter(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w900,
                                          color: _R.rose,
                                        ),
                                      ),
                                    ),
                                    _CountBtn(
                                      icon: Icons.add,
                                      onTap: _guestsCount < 15
                                          ? () => setState(() => _guestsCount++)
                                          : null,
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
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                          color: _statusColor(_rsvpStatus!).withOpacity(0.35)),
                                    ),
                                    child: Text(
                                      'Réponse actuelle : ${_statusLabel(_rsvpStatus!)}',
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.w700,
                                        color: _statusColor(_rsvpStatus!),
                                      ),
                                    ),
                                  ),
                                // 3 boutons
                                Row(
                                  children: [
                                    Expanded(
                                      child: _RsvpBtn(
                                        label: 'Confirmé',
                                        icon: Icons.check_circle_outline,
                                        color: _R.green,
                                        selected: _rsvpStatus == 'confirmed' ||
                                            _rsvpStatus == 'accepted',
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
                                        selected: _rsvpStatus == 'declined' ||
                                            _rsvpStatus == 'no',
                                        loading: _rsvpSaving,
                                        onTap: () => _submitRsvp('declined'),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // ── Actions ─────────────────────────────────────
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: FilledButton.icon(
                              onPressed: _addToCalendar,
                              icon: const Icon(Icons.event_available_rounded),
                              label: Text(
                                'Ajouter à mon calendrier',
                                style: GoogleFonts.inter(fontWeight: FontWeight.w800),
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor: _R.rose,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: OutlinedButton.icon(
                              onPressed: _share,
                              icon: const Icon(Icons.share_outlined),
                              label: Text(
                                'Partager l\'invitation',
                                style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _R.ink,
                                side: const BorderSide(color: _R.border),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextButton(
                            onPressed: () {
                              context.push('/thix-weeding/guest/${widget.weddingId}/rsvp');
                            },
                            child: Text(
                              'Formulaire RSVP détaillé →',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700,
                                color: _R.rose,
                              ),
                            ),
                          ),
                        ],
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
// STUDIO-STYLE INVITE CARD
// ═══════════════════════════════════════════════════════════════════════════
class _StudioInviteCard extends StatelessWidget {
  final String title;
  final String intro;
  final String outro;
  final String couple;
  final String whenLine;
  final String place;
  final String heroUrl;
  final Color accent;
  final Color bg;
  final String uniqueCode;
  final String? guestName;
  final String guestAccessCode;
  final int? tableNumber;
  final String templateId;

  const _StudioInviteCard({
    required this.title,
    required this.intro,
    required this.outro,
    required this.couple,
    required this.whenLine,
    required this.place,
    required this.heroUrl,
    required this.accent,
    required this.bg,
    required this.uniqueCode,
    this.guestName,
    required this.guestAccessCode,
    this.tableNumber,
    this.templateId = '',
  });

  @override
  Widget build(BuildContext context) {
    // Layout type Studio : photo en haut + carte blanche (lisible)
    // évite le texte en désordre sur la photo
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withOpacity(0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Photo ──────────────────────────────────────────
          AspectRatio(
            aspectRatio: 1.05,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (heroUrl.isNotEmpty)
                  Image.network(
                    heroUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(color: bg),
                  )
                else
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color.lerp(bg, accent, 0.2)!, bg],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                // léger voile bas pour transition
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 48,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.white.withOpacity(0.95),
                        ],
                      ),
                    ),
                  ),
                ),
                if (tableNumber != null)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.12),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.table_restaurant_rounded, size: 16, color: accent),
                          const SizedBox(width: 6),
                          Text(
                            'Table $tableNumber',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                              color: _R.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── Contenu texte ordonné ──────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              children: [
                Text(
                  title.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cinzel(
                    fontSize: 11,
                    letterSpacing: 2.5,
                    fontWeight: FontWeight.w600,
                    color: accent,
                  ),
                ),
                if (guestName != null && guestName!.trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Cher(e)',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: _R.inkSoft,
                    ),
                  ),
                  Text(
                    guestName!,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: _R.ink,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  intro,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    color: _R.inkSoft,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  couple,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.greatVibes(
                    fontSize: 34,
                    color: accent,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 12),
                Container(width: 48, height: 1.5, color: accent.withOpacity(0.5)),
                const SizedBox(height: 12),
                Text(
                  whenLine.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cinzel(
                    fontSize: 12,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
                if (place.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    place,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 15,
                      color: _R.ink,
                    ),
                  ),
                ],
                if (outro.trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    outro,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: accent,
                    ),
                  ),
                ],
                const SizedBox(height: 18),

                // ── QR entrée ────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: accent.withOpacity(0.25)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'QR code d\'entrée',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: _R.ink,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: QrImageView(
                          data: guestAccessCode.isNotEmpty
                              ? guestAccessCode
                              : uniqueCode,
                          version: QrVersions.auto,
                          size: 140,
                          backgroundColor: Colors.white,
                          eyeStyle: QrEyeStyle(
                            eyeShape: QrEyeShape.square,
                            color: accent,
                          ),
                          dataModuleStyle: QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.square,
                            color: _R.ink,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        guestAccessCode.isNotEmpty ? guestAccessCode : uniqueCode,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: _R.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'À présenter à l\'entrée de la salle',
                        style: GoogleFonts.inter(fontSize: 11, color: _R.inkSoft),
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
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _R.border),
        boxShadow: [
          BoxShadow(
            color: _R.rose.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: _R.ink,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
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
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _R.roseSoft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: _R.rose, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _R.inkSoft,
                ),
              ),
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
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _R.ink,
                        height: 1.35,
                      ),
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
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: loading ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
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
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: _R.border),
          ),
          child: Icon(icon, size: 18, color: onTap == null ? _R.inkSoft : _R.rose),
        ),
      ),
    );
  }
}
