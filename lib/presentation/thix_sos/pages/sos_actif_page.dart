/// THIX SOS — Écran SOS EN COURS (production)
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/sos_models.dart';
import '../providers/sos_providers.dart';
import '../thix_sos_screen.dart';

class SosActifPage extends ConsumerStatefulWidget {
  const SosActifPage({super.key, required this.incidentId});

  final String incidentId;

  @override
  ConsumerState<SosActifPage> createState() => _SosActifPageState();
}

class _SosActifPageState extends ConsumerState<SosActifPage> {
  Timer? _uiTimer;
  Duration _elapsed = Duration.zero;

  // Variables pour l'escalade
  int _escalationCircle = 1;
  int _escalationLeft = 0;

  @override
  void initState() {
    super.initState();
    _uiTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final incident = ref.read(sosIncidentProvider(widget.incidentId)).valueOrNull;
      if (incident != null && mounted) {
        setState(() => _elapsed = DateTime.now().difference(incident.startedAt));
      }
    });

    // Heartbeat & Callbacks d'escalade
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(sosHeartbeatControllerProvider.notifier).start(widget.incidentId);

      // Branchement de l'interface sur le contrôleur d'escalade
      final escalation = ref.read(sosEscalationProvider);
      escalation.onTick = (circle, left) {
        if (mounted) {
          setState(() {
            _escalationCircle = circle;
            _escalationLeft = left;
          });
        }
      };
      
      escalation.onEvent = (msg) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(msg, style: const TextStyle(color: Colors.white)),
              backgroundColor: const Color(0xFF16161F),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      };
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

  Future<void> _cancelSos(SosIncident incident) async {
    final pin = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _PinDialog(),
    );
    if (pin == null || pin.isEmpty) return;

    // MVP : PIN local simple (à remplacer par hash serveur)
    final ok = await ref.read(sosResolveProvider.notifier).cancel(incident.id);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('SOS annulé'),
          backgroundColor: Color(0xFF16A34A),
        ),
      );
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const ThixSosScreen()),
        (_) => false,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Échec annulation'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final incidentAsync = ref.watch(sosIncidentProvider(widget.incidentId));
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
                child: Text('Incident introuvable', style: TextStyle(color: Colors.white)),
              );
            }

            final circleContacts = contactsAsync.maybeWhen(
              data: (all) =>
                  all.where((c) => c.circle == incident.activeCircle).toList(),
              orElse: () => <SosContact>[],
            );

            return Column(
              children: [
                // Header rouge
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(8, 8, 16, 16),
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
                            onPressed: () => Navigator.maybePop(context),
                          ),
                          Expanded(
                            child: Text(
                              'SOS EN COURS',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const Icon(Icons.shield, color: Colors.white54, size: 22),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _HeaderStat(
                              icon: Icons.timer_outlined,
                              label: 'Durée',
                              value: _elapsedLabel,
                            ),
                          ),
                          Expanded(
                            child: _HeaderStat(
                              icon: Icons.tag,
                              label: 'Identifiant',
                              value: incident.publicId.replaceAll('SOS ', ''),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Status row
                        Row(
                          children: [
                            _StatusChip(
                              icon: Icons.location_on,
                              label: 'Localisation',
                              value: incident.hasLocation ? 'ACTIVE' : 'EN ATTENTE',
                              active: incident.hasLocation,
                            ),
                            const SizedBox(width: 8),
                            _StatusChip(
                              icon: Icons.favorite,
                              label: 'Heartbeat',
                              value: 'ACTIVE',
                              active: true,
                            ),
                            const SizedBox(width: 8),
                            _StatusChip(
                              icon: Icons.cloud_done,
                              label: 'Sauvegarde',
                              value: 'ACTIVE',
                              active: true,
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Appel automatique
                        Text(
                          'APPEL AUTOMATIQUE EN COURS',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white54,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Cercle ${incident.activeCircle} – ${incident.status.labelFr}',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF34D399),
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Nouvel affichage dynamique de l'escalade
                        if (_escalationLeft > 0)
                          Text(
                            'Cercle $_escalationCircle — prochain dans ${_escalationLeft}s',
                            style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
                          ),
                        const SizedBox(height: 12),

                        if (circleContacts.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF16161F),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: Text(
                              'Aucun secours configuré dans ce cercle.\nAjoutez des contacts dans Mes secours.',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: Colors.white54,
                                height: 1.4,
                              ),
                            ),
                          )
                        else
                          ...circleContacts.map(
                            (c) => _ContactCallTile(contact: c),
                          ),

                        const SizedBox(height: 20),

                        // Localisation
                        Text(
                          'LOCALISATION EN DIRECT',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white54,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          height: 140,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1A24),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Stack(
                            children: [
                              const Center(
                                child: Icon(
                                  Icons.my_location,
                                  color: Color(0xFF2563EB),
                                  size: 32,
                                ),
                              ),
                              if (incident.hasLocation)
                                Positioned(
                                  left: 12,
                                  top: 12,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${incident.lastLat!.toStringAsFixed(5)}, '
                                      '${incident.lastLng!.toStringAsFixed(5)}',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Chat + Chambre
                        _ActionBar(
                          title: 'THIX CHAT SOS',
                          subtitle: 'Ouvrir la conversation d\'urgence',
                          icon: Icons.chat_bubble_outline,
                          color: const Color(0xFFA78BFA),
                          onTap: () {},
                        ),
                        const SizedBox(height: 10),
                        _ActionBar(
                          title: 'CHAMBRE DE CRISE',
                          subtitle: 'Ouvrir la chambre de crise',
                          icon: Icons.desktop_windows_outlined,
                          color: const Color(0xFFEF4444),
                          filled: true,
                          onTap: () {},
                        ),
                        const SizedBox(height: 16),

                        // Annuler
                        Material(
                          color: const Color(0xFF16161F),
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            onTap: () => _cancelSos(incident),
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: const Color(0xFFEF4444).withOpacity(0.35),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.lock_outline,
                                      color: Color(0xFFEF4444)),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
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
                                          'Entrez votre code de sécurité',
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
                        const SizedBox(height: 32),
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
}

// ── Widgets internes ──────────────────────────────────────────

class _HeaderStat extends StatelessWidget {
  const _HeaderStat({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white54, size: 18),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(fontSize: 11, color: Colors.white54),
            ),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.active,
  });
  final IconData icon;
  final String label;
  final String value;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? const Color(0xFF34D399) : Colors.white38;
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
            Text(
              label,
              style: GoogleFonts.inter(fontSize: 10, color: Colors.white38),
            ),
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

class _ContactCallTile extends StatelessWidget {
  const _ContactCallTile({required this.contact});
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
            radius: 20,
            backgroundColor: const Color(0xFF374151),
            backgroundImage: contact.photoUrl != null
                ? NetworkImage(contact.photoUrl!)
                : null,
            child: contact.photoUrl == null
                ? Text(
                    contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?',
                    style: const TextStyle(color: Colors.white),
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
                  'Appel en cours…',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF34D399),
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.phone_in_talk, color: Color(0xFF34D399), size: 20),
        ],
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
    this.filled = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? color : const Color(0xFF16161F),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: filled ? null : Border.all(color: Colors.white10),
          ),
          child: Row(
            children: [
              Icon(icon, color: filled ? Colors.white : color, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: filled ? Colors.white70 : Colors.white38,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: filled ? Colors.white70 : Colors.white24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PinDialog extends StatefulWidget {
  const _PinDialog();

  @override
  State<_PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<_PinDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF16161F),
      title: Text(
        'Code de sécurité',
        style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700),
      ),
      content: TextField(
        controller: _ctrl,
        obscureText: true,
        keyboardType: TextInputType.number,
        maxLength: 6,
        style: const TextStyle(color: Colors.white, letterSpacing: 8, fontSize: 20),
        decoration: InputDecoration(
          hintText: '••••',
          hintStyle: const TextStyle(color: Colors.white24, letterSpacing: 8),
          counterText: '',
          filled: true,
          fillColor: Colors.black26,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Retour', style: TextStyle(color: Colors.white54)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
          onPressed: () => Navigator.pop(context, _ctrl.text),
          child: const Text('Confirmer'),
        ),
      ],
    );
  }
}
