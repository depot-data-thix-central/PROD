/// THIX SOS — Chambre de crise (vue victime) — production
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/sos_models.dart';
import '../providers/sos_providers.dart';
import 'sos_pin_page.dart';

class ChambreCrisePage extends ConsumerStatefulWidget {
  const ChambreCrisePage({super.key, required this.incidentId});

  final String incidentId;

  @override
  ConsumerState<ChambreCrisePage> createState() => _ChambreCrisePageState();
}

class _ChambreCrisePageState extends ConsumerState<ChambreCrisePage> {
  Timer? _uiTimer;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _uiTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final incident =
          ref.read(sosIncidentProvider(widget.incidentId)).valueOrNull;
      if (incident != null && mounted) {
        setState(() => _elapsed = DateTime.now().difference(incident.startedAt));
      }
    });
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

            final contacts = contactsAsync.valueOrNull ?? [];

            return Column(
              children: [
                _Header(
                  publicId: incident.publicId,
                  elapsed: _elapsedLabel,
                  onBack: () => Navigator.pop(context),
                  onEnd: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SosPinPage(
                          incidentId: incident.id,
                          mode: SosPinMode.resolve,
                        ),
                      ),
                    );
                  },
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                    children: [
                      // Statut
                      _StatusRow(incident: incident),
                      const SizedBox(height: 16),

                      // Carte live
                      _section('LOCALISATION EN DIRECT'),
                      const SizedBox(height: 8),
                      _LiveMapCard(incident: incident),
                      const SizedBox(height: 20),

                      // Secours connectés
                      _section('SECOURS — CERCLE ${incident.activeCircle}'),
                      const SizedBox(height: 8),
                      if (contacts.where((c) => c.circle == incident.activeCircle).isEmpty)
                        _EmptyBox('Aucun secours dans ce cercle')
                      else
                        ...contacts
                            .where((c) => c.circle == incident.activeCircle)
                            .map((c) => _ResponderTile(contact: c)),

                      const SizedBox(height: 20),

                      // Actions com
                      _section('COMMUNICATION'),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _ComButton(
                              icon: Icons.chat_bubble_outline,
                              label: 'Chat SOS',
                              color: const Color(0xFFA78BFA),
                              onTap: () {},
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _ComButton(
                              icon: Icons.phone_in_talk,
                              label: 'Appel',
                              color: const Color(0xFF34D399),
                              onTap: () {},
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _ComButton(
                              icon: Icons.videocam_outlined,
                              label: 'Vidéo',
                              color: const Color(0xFF60A5FA),
                              onTap: () {},
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Messages rapides
                      _section('MESSAGES RAPIDES'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: const [
                          _QuickMsg('🚨 J\'AI BESOIN D\'AIDE'),
                          _QuickMsg('🤫 JE NE PEUX PAS PARLER'),
                          _QuickMsg('📍 JE SUIS ICI'),
                          _QuickMsg('🏥 JE SUIS BLESSÉ'),
                          _QuickMsg('👤 JE SUIS SUIVI'),
                          _QuickMsg('🟢 JE VAIS BIEN'),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Timeline events
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
                        error: (_, __) => _EmptyBox('Impossible de charger les événements'),
                        data: (events) {
                          if (events.isEmpty) {
                            return _EmptyBox('Aucun événement');
                          }
                          return Column(
                            children: events
                                .take(20)
                                .map((e) => _EventTile(event: e))
                                .toList(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

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

// ── Header ────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({
    required this.publicId,
    required this.elapsed,
    required this.onBack,
    required this.onEnd,
  });

  final String publicId;
  final String elapsed;
  final VoidCallback onBack;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(4, 4, 12, 14),
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
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.incident});
  final SosIncident incident;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF16161F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withOpacity(0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '🔴 ${incident.status.labelFr.toUpperCase()}',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: const Color(0xFFFECACA),
              ),
            ),
          ),
          const Spacer(),
          if (incident.batteryPct != null)
            Row(
              children: [
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
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
        ],
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                        'MAJ ${_fmtTime(incident.lastLocationAt!)}',
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

  String _fmtTime(DateTime d) =>
      '\( {d.hour.toString().padLeft(2, '0')}: \){d.minute.toString().padLeft(2, '0')}:${d.second.toString().padLeft(2, '0')}';
}

class _ResponderTile extends StatelessWidget {
  const _ResponderTile({required this.contact});
  final SosContact contact;

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
                    contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?',
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
                  contact.available ? 'Disponible' : 'Indisponible',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: contact.available
                        ? const Color(0xFF34D399)
                        : Colors.white38,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.phone, color: Color(0xFF34D399), size: 20),
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
  const _QuickMsg(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF16161F),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: () {
          // TODO: envoyer message SOS chat
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(label),
              backgroundColor: const Color(0xFF16161F),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white12),
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white70,
            ),
          ),
        ),
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({required this.event});
  final SosEvent event;

  @override
  Widget build(BuildContext context) {
    final t = event.createdAt;
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
        style: GoogleFonts.inter(fontSize: 13, color: Colors.white38),
      ),
    );
  }
}
