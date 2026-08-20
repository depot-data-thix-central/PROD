/// THIX SOS — Historique des incidents (production)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/sos_models.dart';
import '../providers/sos_providers.dart';
import 'sos_actif_page.dart';

class MesIncidentsPage extends ConsumerWidget {
  const MesIncidentsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(sosHistoryProvider);
    final activeAsync = ref.watch(activeSosProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0F),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Mes incidents',
          style: GoogleFonts.inter(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white54),
            onPressed: () {
              ref.invalidate(sosHistoryProvider);
              ref.invalidate(activeSosProvider);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        color: const Color(0xFFEF4444),
        backgroundColor: const Color(0xFF16161F),
        onRefresh: () async {
          ref.invalidate(sosHistoryProvider);
          ref.invalidate(activeSosProvider);
        },
        child: historyAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: Color(0xFFEF4444)),
          ),
          error: (e, _) => ListView(
            children: [
              const SizedBox(height: 80),
              const Icon(Icons.error_outline, color: Colors.redAccent, size: 40),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  'Impossible de charger l\'historique',
                  style: GoogleFonts.inter(color: Colors.redAccent),
                ),
              ),
              Center(
                child: TextButton(
                  onPressed: () => ref.invalidate(sosHistoryProvider),
                  child: const Text('Réessayer'),
                ),
              ),
            ],
          ),
          data: (incidents) {
            final active = activeAsync.valueOrNull;
            final past = incidents
                .where((i) => active == null || i.id != active.id)
                .toList();

            if (incidents.isEmpty) {
              return ListView(
                children: [
                  const SizedBox(height: 100),
                  Icon(Icons.folder_open, size: 56, color: Colors.white24),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      'Aucun incident pour le moment',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        color: Colors.white54,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: Text(
                      'Vos SOS apparaîtront ici',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.white30,
                      ),
                    ),
                  ),
                ],
              );
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                if (active != null && active.isActive) ...[
                  Text(
                    'EN COURS',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFEF4444),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _IncidentCard(
                    incident: active,
                    highlight: true,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SosActifPage(incidentId: active.id),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                ],
                if (past.isNotEmpty) ...[
                  Text(
                    'HISTORIQUE',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white54,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...past.map(
                    (i) => _IncidentCard(
                      incident: i,
                      onTap: () {
                        // TODO: IncidentDetailPage
                      },
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _IncidentCard extends StatelessWidget {
  const _IncidentCard({
    required this.incident,
    this.onTap,
    this.highlight = false,
  });

  final SosIncident incident;
  final VoidCallback? onTap;
  final bool highlight;

  Color get _statusColor {
    if (incident.status == SosStatus.resolved) return const Color(0xFF34D399);
    if (incident.status == SosStatus.cancelled) return Colors.white38;
    return const Color(0xFFEF4444);
  }

  String _formatDate(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final time =
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    if (day == today) return 'Aujourd\'hui, $time';
    if (day == today.subtract(const Duration(days: 1))) return 'Hier, $time';
    return '\( {d.day.toString().padLeft(2, '0')}/ \){d.month.toString().padLeft(2, '0')}/${d.year}, $time';
  }

  String _durationLabel(SosIncident i) {
    final end = i.resolvedAt ?? DateTime.now();
    final d = end.difference(i.startedAt);
    if (d.inHours > 0) {
      return '${d.inHours}h ${(d.inMinutes % 60).toString().padLeft(2, '0')}min';
    }
    return '${d.inMinutes} min';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: highlight
            ? const Color(0xFF7F1D1D).withOpacity(0.35)
            : const Color(0xFF16161F),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: highlight
                    ? const Color(0xFFEF4444).withOpacity(0.45)
                    : Colors.white10,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    highlight ? Icons.sos : Icons.folder_outlined,
                    color: _statusColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        incident.publicId,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatDate(incident.startedAt),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.white54,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${incident.status.labelFr} · ${_durationLabel(incident)}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: highlight ? const Color(0xFFEF4444) : Colors.white24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
