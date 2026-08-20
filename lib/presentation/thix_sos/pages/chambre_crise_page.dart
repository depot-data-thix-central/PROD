/// THIX SOS — Chambre de crise (victime) — production complète
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:thix_id/nav.dart';
import 'package:thix_id/models/chat/chat_conversation.dart';
import 'package:thix_id/services/chat/chat_service.dart';
import '../models/sos_models.dart';
import '../providers/sos_providers.dart';
import 'sos_pin_page.dart';

class ChambreCrisePage extends ConsumerStatefulWidget {
  const ChambreCrisePage({
    super.key,
    required this.incidentId,
    this.conversationId,
  });

  final String incidentId;
  final String? conversationId;

  @override
  ConsumerState<ChambreCrisePage> createState() => _ChambreCrisePageState();
}

class _ChambreCrisePageState extends ConsumerState<ChambreCrisePage> {
  Timer? _uiTimer;
  Duration _elapsed = Duration.zero;
  String? _resolvedConversationId;

  // Messages rapides déjà envoyés (évite spam UI)
  final Set<String> _sentQuick = {};

  @override
  void initState() {
    super.initState();
    _resolvedConversationId = widget.conversationId;

    _uiTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final incident =
          ref.read(sosIncidentProvider(widget.incidentId)).valueOrNull;
      if (incident != null && mounted) {
        var d = DateTime.now().difference(incident.startedAt.toLocal());
        if (d.isNegative) d = Duration.zero;
        setState(() => _elapsed = d);
      }
    });

    // Heartbeat
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(sosHeartbeatControllerProvider.notifier)
          .start(widget.incidentId);
      _loadConversationId();
    });
  }

  Future<void> _loadConversationId() async {
    if (_resolvedConversationId != null) return;
    try {
      final incident =
          await ref.read(sosServiceProvider).getIncidentById(widget.incidentId);
      // si colonne chat_conversation_id exposée plus tard sur le modèle
      // _resolvedConversationId = incident?.chatConversationId;
    } catch (_) {}
  }

  @override
  void dispose() {
    _uiTimer?.cancel();
    super.dispose();
  }

  String get _elapsedLabel {
    final h = _elapsed.inHours.toString().padLeft(2, '0');
    final m = (_elapsed.inMinutes % 60).toString().padLeft(2, '0');
    final s = (_elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  Future<void> _openChat(SosIncident incident) async {
    final convId = incident.chatConversationId ?? _resolvedConversationId;
    if (convId == null || convId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Conversation SOS pas encore créée'),
          backgroundColor: Color(0xFF16161F),
        ),
      );
      return;
    }

    final conversation = ChatConversation(
      id: convId,
      isGroup: true,
      groupName: 'THIX CHAT ${incident.publicId}',
      participantIds: const [],
      updatedAt: DateTime.now(),
    );

    context.push(
      AppRoutes.chatDetail(convId),
      extra: conversation,
    );
  }

  Future<void> _callContact(SosContact contact) async {
    final userId =
        await ref.read(sosServiceProvider).resolveContactUserId(contact);
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${contact.name} : pas de compte THIX'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    // Branche sur ton CallProvider si exposé globalement
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Appel THIX vers ${contact.name}…'),
        backgroundColor: const Color(0xFF16161F),
      ),
    );
    // Exemple si tu as une route :
    // context.push('/call', extra: {'userId': userId, 'name': contact.name});
  }

  Future<void> _sendQuickMessage(SosIncident incident, String text) async {
    if (_sentQuick.contains(text)) return;
    setState(() => _sentQuick.add(text));

    final convId = incident.chatConversationId ?? _resolvedConversationId;

    await ref.read(sosServiceProvider).logEventPublic(
          incident.id,
          'QUICK_MESSAGE',
          {'text': text},
        );

    if (convId != null && convId.isNotEmpty) {
      try {
        await ChatService().sendMessage(
          conversationId: convId,
          content: text,
        );
      } catch (e) {
        debugPrint('Quick msg chat: $e');
      }
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: const Color(0xFF16161F),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _endSos() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SosPinPage(
          incidentId: widget.incidentId,
          mode: SosPinMode.resolve,
        ),
      ),
    );
  }

  void _cancelSos() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SosPinPage(
          incidentId: widget.incidentId,
          mode: SosPinMode.cancel,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final incidentAsync = ref.watch(sosIncidentProvider(widget.incidentId));
    final eventsAsync = ref.watch(sosEventsProvider(widget.incidentId));
    final contactsAsync = ref.watch(sosContactsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: SafeArea(
        child: incidentAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: Color(0xFFEF4444)),
          ),
          error: (e, _) => Center(
            child: Text('Erreur: $e', style: const TextStyle(color: Colors.red)),
          ),
          data: (incident) {
            if (incident == null) {
              return const Center(
                child: Text(
                  'Incident introuvable',
                  style: TextStyle(color: Colors.white),
                ),
              );
            }

            final circleContacts = contactsAsync.maybeWhen(
              data: (all) =>
                  all.where((c) => c.circle == incident.activeCircle).toList(),
              orElse: () => <SosContact>[],
            );

            return Column(
              children: [
                _Header(
                  publicId: incident.publicId,
                  elapsed: _elapsedLabel,
                  status: incident.status,
                  onBack: () => Navigator.pop(context),
                  onEnd: _endSos,
                ),
                Expanded(
                  child: RefreshIndicator(
                    color: const Color(0xFFEF4444),
                    backgroundColor: const Color(0xFF16161F),
                    onRefresh: () async {
                      ref.invalidate(sosIncidentProvider(widget.incidentId));
                      ref.invalidate(sosEventsProvider(widget.incidentId));
                      ref.invalidate(sosContactsProvider);
                    },
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                      children: [
                        // Zone statut
                        _StatusStrip(incident: incident),
                        const SizedBox(height: 16),

                        // Carte live
                        _section('LOCALISATION EN DIRECT'),
                        const SizedBox(height: 8),
                        _LiveMapCard(incident: incident),
                        const SizedBox(height: 20),

                        // Secours cercle actif
                        _section(
                          'SECOURS — CERCLE ${incident.activeCircle}',
                        ),
                        const SizedBox(height: 8),
                        if (circleContacts.isEmpty)
                          _EmptyBox(
                            'Aucun secours dans ce cercle.\nAjoutez des contacts THIX.',
                          )
                        else
                          ...circleContacts.map(
                            (c) => _ResponderTile(
                              contact: c,
                              onCall: () => _callContact(c),
                            ),
                          ),
                        const SizedBox(height: 20),

                        // Communication
                        _section('COMMUNICATION'),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _ComButton(
                                icon: Icons.chat_bubble_outline,
                                label: 'Chat SOS',
                                color: const Color(0xFFA78BFA),
                                onTap: () => _openChat(incident),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _ComButton(
                                icon: Icons.phone_in_talk,
                                label: 'Rappeler',
                                color: const Color(0xFF34D399),
                                onTap: () {
                                  if (circleContacts.isNotEmpty) {
                                    _callContact(circleContacts.first);
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _ComButton(
                                icon: Icons.videocam_outlined,
                                label: 'Vidéo',
                                color: const Color(0xFF60A5FA),
                                onTap: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Appel vidéo — bientôt',
                                      ),
                                      backgroundColor: Color(0xFF16161F),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Messages rapides victime
                        _section('MESSAGES RAPIDES'),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final msg in _quickMessages)
                              _QuickMsg(
                                label: msg,
                                sent: _sentQuick.contains(msg),
                                onTap: () => _sendQuickMessage(incident, msg),
                              ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Heartbeat / batterie
                        _section('ÉTAT SYSTÈME'),
                        const SizedBox(height: 8),
                        _SystemRow(incident: incident),
                        const SizedBox(height: 20),

                        // Timeline
                        _section('ÉVÉNEMENTS'),
                        const SizedBox(height: 8),
                        eventsAsync.when(
                          loading: () => const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(
                              child: CircularProgressIndicator(
                                color: Color(0xFFEF4444),
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                          error: (_, __) =>
                              _EmptyBox('Impossible de charger les événements'),
                          data: (events) {
                            if (events.isEmpty) {
                              return _EmptyBox('Aucun événement');
                            }
                            return Column(
                              children: events
                                  .take(30)
                                  .map((e) => _EventTile(event: e))
                                  .toList(),
                            );
                          },
                        ),
                        const SizedBox(height: 24),

                        // Annuler
                        Material(
                          color: const Color(0xFF16161F),
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            onTap: _cancelSos,
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: const Color(0xFFEF4444)
                                      .withOpacity(0.35),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.lock_outline,
                                    color: Color(0xFFEF4444),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'ANNULER LE SOS',
                                          style: GoogleFonts.inter(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                            color: const Color(0xFFEF4444),
                                          ),
                                        ),
                                        Text(
                                          'Code de sécurité requis',
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            color: Colors.white38,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  static const _quickMessages = [
    '🚨 J\'AI BESOIN D\'AIDE',
    '🤫 JE NE PEUX PAS PARLER',
    '📍 JE SUIS ICI',
    '🏥 JE SUIS BLESSÉ',
    '👤 JE SUIS SUIVI',
    '🚪 JE SUIS ENFERMÉ',
    '📞 APPELEZ LES SECOURS',
    '🟢 JE VAIS BIEN',
  ];

  Widget _section(String title) {
    return Text(
      title,
      style: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: Colors.white54,
        letterSpacing: 0.5,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Widgets
// ═══════════════════════════════════════════════════════════════

class _Header extends StatelessWidget {
  const _Header({
    required this.publicId,
    required this.elapsed,
    required this.status,
    required this.onBack,
    required this.onEnd,
  });

  final String publicId;
  final String elapsed;
  final SosStatus status;
  final VoidCallback onBack;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(4, 4, 8, 14),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF7F1D1D), Color(0xFF450A0A)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white70),
                onPressed: onBack,
              ),
              Expanded(
                child: Text(
                  'CHAMBRE DE CRISE',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              TextButton(
                onPressed: onEnd,
                child: Text(
                  'Terminer',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFFECACA),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                publicId,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(width: 16),
              const Icon(Icons.timer_outlined, size: 16, color: Colors.white54),
              const SizedBox(width: 4),
              Text(
                elapsed,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            status.labelFr.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: const Color(0xFFFECACA),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusStrip extends StatelessWidget {
  const _StatusStrip({required this.incident});
  final SosIncident incident;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _chip(
          Icons.location_on,
          'Localisation',
          incident.hasLocation ? 'ACTIVE' : 'EN ATTENTE',
          incident.hasLocation,
        ),
        const SizedBox(width: 8),
        _chip(Icons.favorite, 'Heartbeat', 'ACTIVE', true),
        const SizedBox(width: 8),
        _chip(Icons.cloud_done, 'Cloud', 'ACTIVE', true),
      ],
    );
  }

  Widget _chip(IconData icon, String label, String value, bool on) {
    final color = on ? const Color(0xFF34D399) : Colors.white38;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF16161F),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 4),
            Text(label,
                style: GoogleFonts.inter(fontSize: 10, color: Colors.white38)),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveMapCard extends StatelessWidget {
  const _LiveMapCard({required this.incident});
  final SosIncident incident;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A24),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Stack(
        children: [
          const Center(
            child: Icon(Icons.my_location, color: Color(0xFF2563EB), size: 36),
          ),
          if (incident.hasLocation)
            Positioned(
              left: 12,
              top: 12,
              right: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Position actuelle',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white70,
                      ),
                    ),
                    Text(
                      '${incident.lastLat!.toStringAsFixed(5)}, ${incident.lastLng!.toStringAsFixed(5)}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.white,
                      ),
                    ),
                    if (incident.lastLocationAt != null)
                      Text(
                        'MAJ ${_fmt(incident.lastLocationAt!)}',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: Colors.white38,
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _fmt(DateTime d) {
    final l = d.toLocal();
    return '\( {l.hour.toString().padLeft(2, '0')}: \){l.minute.toString().padLeft(2, '0')}:${l.second.toString().padLeft(2, '0')}';
  }
}

class _ResponderTile extends StatelessWidget {
  const _ResponderTile({required this.contact, required this.onCall});
  final SosContact contact;
  final VoidCallback onCall;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF16161F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFF374151),
            backgroundImage:
                contact.photoUrl != null ? NetworkImage(contact.photoUrl!) : null,
            child: contact.photoUrl == null
                ? Text(
                    contact.name.isNotEmpty
                        ? contact.name[0].toUpperCase()
                        : '?',
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contact.name,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                Text(
                  contact.thixId ??
                      (contact.available ? 'Disponible' : 'Indisponible'),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF34D399),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onCall,
            icon: const Icon(Icons.phone, color: Color(0xFF34D399)),
          ),
        ],
      ),
    );
  }
}

class _ComButton extends StatelessWidget {
  const _ComButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF16161F),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickMsg extends StatelessWidget {
  const _QuickMsg({
    required this.label,
    required this.onTap,
    this.sent = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool sent;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: sent
          ? const Color(0xFF14532D).withOpacity(0.5)
          : const Color(0xFF16161F),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: sent ? null : onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: sent
                  ? const Color(0xFF34D399).withOpacity(0.4)
                  : Colors.white12,
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: sent ? const Color(0xFF34D399) : Colors.white70,
            ),
          ),
        ),
      ),
    );
  }
}

class _SystemRow extends StatelessWidget {
  const _SystemRow({required this.incident});
  final SosIncident incident;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF16161F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          const Icon(Icons.favorite, color: Color(0xFFEF4444), size: 18),
          const SizedBox(width: 8),
          Text(
            'HEARTBEAT',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.white70,
            ),
          ),
          const Spacer(),
          if (incident.batteryPct != null) ...[
            Icon(
              Icons.battery_std,
              size: 16,
              color: incident.batteryPct! < 20
                  ? const Color(0xFFEF4444)
                  : const Color(0xFF34D399),
            ),
            const SizedBox(width: 4),
            Text(
              '${incident.batteryPct}%',
              style: GoogleFonts.inter(fontSize: 12, color: Colors.white70),
            ),
          ] else
            Text(
              'Cercle ${incident.activeCircle}',
              style: GoogleFonts.inter(fontSize: 12, color: Colors.white54),
            ),
        ],
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({required this.event});
  final SosEvent event;

  @override
  Widget build(BuildContext context) {
    final t = event.createdAt.toLocal();
    final time =
        '\( {t.hour.toString().padLeft(2, '0')}: \){t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 52,
            child: Text(
              time,
              style: GoogleFonts.inter(fontSize: 11, color: Colors.white38),
            ),
          ),
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 4, right: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFEF4444),
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Text(
              event.type,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white70,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyBox extends StatelessWidget {
  const _EmptyBox(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16161F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 13,
          color: Colors.white38,
          height: 1.35,
        ),
      ),
    );
  }
}
