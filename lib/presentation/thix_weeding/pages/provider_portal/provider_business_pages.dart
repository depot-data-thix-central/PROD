// lib/presentation/thix_weeding/pages/provider_portal/provider_business_pages.dart
// ============================================================================
// THIX WEDDING PROVIDER BUSINESS (PRODUCTION ENTERPRISE)
// ✅ Gestion des réservations (Liste + Statut)
// ✅ Gestion des tâches (Checklist interactive)
// ============================================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../models/provider_models.dart';
import '../../providers/provider_providers.dart';

class _P {
  static const Color bg = Color(0xFFFAFAFA);
  static const Color surface = Colors.white;
  static const Color rose = Color(0xFFFF4D6D);
  static const Color ink = Color(0xFF1A1A2E);
  static const Color inkSoft = Color(0xFF6B7280);
  static const Color line = Color(0xFFE5E7EB);
  static const Color green = Color(0xFF10B981);
}

// ═══════════════════════════════════════════════════════════════════════════
// RÉSERVATIONS
// ═══════════════════════════════════════════════════════════════════════════
class ProviderReservationsPage extends ConsumerWidget {
  final ThixProviderModel provider;
  const ProviderReservationsPage({super.key, required this.provider});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reservationsAsync = ref.watch(providerReservationsProvider(
      ProviderReservationsParams(providerId: provider.id),
    ));

    return Scaffold(
      backgroundColor: _P.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Réservations',
          style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w900, color: _P.ink),
        ),
        centerTitle: false,
      ),
      body: reservationsAsync.when(
        data: (reservations) {
          if (reservations.isEmpty) {
            return const Center(child: Text('Aucune réservation'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: reservations.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _ReservationListItem(
              reservation: reservations[i],
              onUpdateStatus: (status) {
                ref.read(updateReservationStatusProvider)(reservations[i].id, status);
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur: $e')),
      ),
    );
  }
}

class _ReservationListItem extends StatelessWidget {
  final ProviderReservationModel reservation;
  final Function(ReservationStatus) onUpdateStatus;

  const _ReservationListItem({required this.reservation, required this.onUpdateStatus});

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('dd MMM yyyy', 'fr_FR').format(reservation.eventDate);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _P.line),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _P.rose.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.person, color: _P.rose, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reservation.clientName,
                      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: _P.ink),
                    ),
                    Text(
                      reservation.clientPhone,
                      style: GoogleFonts.inter(fontSize: 12, color: _P.inkSoft),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(reservation.status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  reservation.status.name.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: _getStatusColor(reservation.status),
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            children: [
              const Icon(Icons.calendar_today, size: 16, color: _P.inkSoft),
              const SizedBox(width: 6),
              Text(dateStr, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: _P.ink)),
              const Spacer(),
              if (reservation.totalPrice != null)
                Text(
                  '\$${reservation.totalPrice}',
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900, color: _P.rose),
                ),
            ],
          ),
          if (reservation.status == ReservationStatus.pending) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => onUpdateStatus(ReservationStatus.confirmed),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _P.green,
                      side: const BorderSide(color: _P.green),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Confirmer'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => onUpdateStatus(ReservationStatus.cancelled),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Refuser'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Color _getStatusColor(ReservationStatus status) {
    switch (status) {
      case ReservationStatus.pending: return Colors.orange;
      case ReservationStatus.confirmed: return _P.green;
      case ReservationStatus.completed: return Colors.blue;
      case ReservationStatus.cancelled: return Colors.red;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TÂCHES
// ═══════════════════════════════════════════════════════════════════════════
class ProviderTasksPage extends ConsumerWidget {
  final ThixProviderModel provider;
  const ProviderTasksPage({super.key, required this.provider});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(providerTasksProvider(
      ProviderTasksParams(providerId: provider.id),
    ));

    return Scaffold(
      backgroundColor: _P.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Mes Tâches',
          style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w900, color: _P.ink),
        ),
        centerTitle: false,
      ),
      body: tasksAsync.when(
        data: (tasks) {
          if (tasks.isEmpty) {
            return const Center(child: Text('Aucune tâche assignée'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: tasks.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _TaskListItem(
              task: tasks[i],
              onToggle: (completed) {
                ref.read(updateTaskStatusProvider)(
                  tasks[i].id,
                  completed ? TaskStatus.completed : TaskStatus.assigned,
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur: $e')),
      ),
    );
  }
}

class _TaskListItem extends StatelessWidget {
  final ProviderTaskModel task;
  final Function(bool) onToggle;

  const _TaskListItem({required this.task, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final isCompleted = task.status == TaskStatus.completed;
    final isHighPriority = task.priority == 1;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _P.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => onToggle(!isCompleted),
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCompleted ? _P.green : Colors.transparent,
                border: Border.all(color: isCompleted ? _P.green : _P.line, width: 2),
              ),
              child: isCompleted
                  ? const Icon(Icons.check, color: Colors.white, size: 18)
                  : null,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isCompleted ? _P.inkSoft : _P.ink,
                    decoration: isCompleted ? TextDecoration.lineThrough : null,
                  ),
                ),
                if (task.description != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    task.description!,
                    style: GoogleFonts.inter(fontSize: 13, color: _P.inkSoft),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 14, color: _P.inkSoft),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('dd MMM, HH:mm', 'fr_FR').format(task.dueDateTime),
                      style: GoogleFonts.inter(fontSize: 12, color: _P.inkSoft),
                    ),
                    if (isHighPriority) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _P.rose.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'URGENT',
                          style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: _P.rose),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
