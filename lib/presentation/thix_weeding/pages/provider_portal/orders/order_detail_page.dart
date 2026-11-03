// lib/presentation/thix_weeding/pages/provider_portal/orders/order_detail_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'order_models.dart';
import 'orders_provider.dart';
import '../traiteur/traiteur_menu_page.dart';

/// ═══════════════════════════════════════════════════════════════════════
/// THIX WEDDING — DÉTAIL COMMANDE + WORKFLOW (Production v2)
/// ✅ Timeline complète des actions
/// ✅ Workflow de statut avec confirmation
/// ✅ Gestion paiement
/// ✅ Menu traiteur intégré
/// ✅ Notes et commentaires
/// ✅ Actions contextuelles
/// ═══════════════════════════════════════════════════════════════════════

class _P {
  static const Color bg = Color(0xFFFAFAFA);
  static const Color surface = Colors.white;
  static const Color rose = Color(0xFFFF4D6D);
  static const Color roseLight = Color(0xFFFF85A1);
  static const Color ink = Color(0xFF1A1A2E);
  static const Color inkSoft = Color(0xFF6B7280);
  static const Color line = Color(0xFFE5E7EB);
  static const Color green = Color(0xFF10B981);
  static const Color blue = Color(0xFF3B82F6);
  static const Color amber = Color(0xFFF59E0B);
  static const Color purple = Color(0xFF8B5CF6);
  static const Color red = Color(0xFFEF4444);
}

class OrderDetailPage extends ConsumerStatefulWidget {
  final WeddingOrder order;
  final String providerId;

  const OrderDetailPage({
    super.key,
    required this.order,
    required this.providerId,
  });

  @override
  ConsumerState<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends ConsumerState<OrderDetailPage> {
  late WeddingOrder _currentOrder;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _currentOrder = widget.order;
  }

  Future<void> _updateStatus(OrderStatus newStatus) async {
    HapticFeedback.mediumImpact();

    // Confirmation pour les actions importantes
    if (newStatus == OrderStatus.cancelled) {
      final confirmed = await _showCancelConfirmation();
      if (!confirmed) return;
    }

    setState(() => _isProcessing = true);

    try {
      await ref.read(ordersProvider(widget.providerId).notifier).updateOrderStatus(
            orderId: _currentOrder.id,
            newStatus: newStatus,
            performedBy: 'Prestataire',
            performedByRole: 'provider',
          );

      // Mettre à jour localement
      setState(() {
        _currentOrder = _currentOrder.copyWith(
          status: newStatus,
          timeline: [
            ..._currentOrder.timeline,
            OrderTimeline(
              action: 'Statut changé: ${_currentOrder.statusDisplayName} → ${newStatus.displayName}',
              timestamp: DateTime.now(),
              performedBy: 'Prestataire',
              performedByRole: 'provider',
            ),
          ],
        );
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Statut mis à jour: ${newStatus.displayName}',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
            backgroundColor: _P.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: _P.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<bool> _showCancelConfirmation() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: _P.red, size: 24),
                const SizedBox(width: 12),
                Text(
                  'Annuler la commande ?',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ],
            ),
            content: Text(
              'Cette action est irréversible. Le client sera notifié de l\'annulation.',
              style: GoogleFonts.inter(color: _P.inkSoft, fontSize: 13),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  'Retour',
                  style: GoogleFonts.inter(color: _P.inkSoft, fontWeight: FontWeight.w600),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _P.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Confirmer l\'annulation',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _updatePayment() async {
    final amountCtrl = TextEditingController(text: _currentOrder.paidAmount?.toStringAsFixed(0) ?? '0');

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Mettre à jour le paiement',
          style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Montant total: ${_currentOrder.totalAmount.toStringAsFixed(0)}\$',
              style: GoogleFonts.inter(fontSize: 13, color: _P.inkSoft),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Montant payé',
                prefixIcon: const Icon(Icons.attach_money),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Annuler',
              style: GoogleFonts.inter(color: _P.inkSoft, fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final amount = double.tryParse(amountCtrl.text) ?? 0;
              final status = amount >= _currentOrder.totalAmount
                  ? PaymentStatus.paid
                  : amount > 0
                      ? PaymentStatus.partial
                      : PaymentStatus.pending;

              ref.read(ordersProvider(widget.providerId).notifier).updatePayment(
                    orderId: _currentOrder.id,
                    amount: amount,
                    status: status,
                  );

              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _P.rose,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Enregistrer',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  void _openTraiteurMenu() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TraiteurMenuPage(
          orderId: _currentOrder.id,
          menuId: _currentOrder.menuId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final daysUntil = _currentOrder.daysUntilEvent;

    return Scaffold(
      backgroundColor: _P.bg,
      appBar: AppBar(
        backgroundColor: _P.bg,
        elevation: 0,
        title: Text(
          'Commande #${_currentOrder.id.substring(0, 8)}',
          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: _P.ink),
        ),
        actions: [
          if (_currentOrder.isTraiteur)
            IconButton(
              icon: const Icon(Icons.restaurant_menu_rounded, color: _P.amber),
              onPressed: _openTraiteurMenu,
              tooltip: 'Menu traiteur',
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: _P.ink),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (value) {
              switch (value) {
                case 'payment':
                  _updatePayment();
                  break;
                case 'call':
                  // TODO: Appeler le client
                  break;
                case 'email':
                  // TODO: Envoyer un email
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'payment',
                child: Row(
                  children: [
                    const Icon(Icons.payment_rounded, size: 18, color: _P.green),
                    const SizedBox(width: 8),
                    Text(
                      'Mettre à jour paiement',
                      style: GoogleFonts.inter(fontSize: 13),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'call',
                child: Row(
                  children: [
                    const Icon(Icons.phone_rounded, size: 18, color: _P.blue),
                    const SizedBox(width: 8),
                    Text(
                      'Appeler le client',
                      style: GoogleFonts.inter(fontSize: 13),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'email',
                child: Row(
                  children: [
                    const Icon(Icons.email_rounded, size: 18, color: _P.purple),
                    const SizedBox(width: 8),
                    Text(
                      'Envoyer un email',
                      style: GoogleFonts.inter(fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isProcessing
          ? const Center(child: CircularProgressIndicator(color: _P.rose))
          : RefreshIndicator(
              onRefresh: () async {
                // TODO: Refresh la commande
              },
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ═══════════════ EN-TÊTE STATUT ═══════════════
                  _StatusHeader(order: _currentOrder),
                  const SizedBox(height: 16),

                  // ═══════════════ ALERTE URGENCE ═══════════════
                  if (_currentOrder.isUrgent)
                    _UrgentBanner(daysUntil: daysUntil),
                  if (_currentOrder.isUrgent) const SizedBox(height: 16),

                  // ═══════════════ INFORMATIONS CLIENT ═══════════════
                  _ClientInfoCard(order: _currentOrder),
                  const SizedBox(height: 16),

                  // ═══════════════ INFORMATIONS COMMANDE ═══════════════
                  _OrderInfoCard(order: _currentOrder),
                  const SizedBox(height: 16),

                  // ═══════════════ PAIEMENT ═══════════════
                  _PaymentCard(order: _currentOrder, onUpdatePayment: _updatePayment),
                  const SizedBox(height: 16),

                  // ═══════════════ MENU TRAITEUR (si applicable) ═══════════════
                  if (_currentOrder.isTraiteur)
                    _TraiteurMenuCard(order: _currentOrder, onOpenMenu: _openTraiteurMenu),
                  if (_currentOrder.isTraiteur) const SizedBox(height: 16),

                  // ═══════════════ DONNÉES SPÉCIFIQUES ═══════════════
                  if (_currentOrder.orderData.isNotEmpty)
                    _SpecificDataCard(order: _currentOrder),
                  if (_currentOrder.orderData.isNotEmpty) const SizedBox(height: 16),

                  // ═══════════════ NOTES ═══════════════
                  if (_currentOrder.notes != null && _currentOrder.notes!.isNotEmpty)
                    _NotesCard(notes: _currentOrder.notes!),
                  if (_currentOrder.notes != null && _currentOrder.notes!.isNotEmpty)
                    const SizedBox(height: 16),

                  // ═══════════════ TIMELINE ═══════════════
                  _TimelineCard(order: _currentOrder),
                  const SizedBox(height: 16),

                  // ═══════════════ ACTIONS ═══════════════
                  _ActionsCard(
                    order: _currentOrder,
                    onUpdateStatus: _updateStatus,
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// WIDGETS SECTIONS
// ═══════════════════════════════════════════════════════════════════════

class _StatusHeader extends StatelessWidget {
  final WeddingOrder order;

  const _StatusHeader({required this.order});

  @override
  Widget build(BuildContext context) {
    final statusColor = order.status.color;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [statusColor.withOpacity(0.9), statusColor.withOpacity(0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(order.status.icon, color: Colors.white, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.status.displayName,
                      style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      order.offerTitle,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.9),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _StatusInfo(
                  label: 'Commande',
                  value: DateFormat('dd MMM', 'fr_FR').format(order.orderDate),
                ),
              ),
              Expanded(
                child: _StatusInfo(
                  label: 'Événement',
                  value: DateFormat('dd MMM', 'fr_FR').format(order.eventDate),
                ),
              ),
              Expanded(
                child: _StatusInfo(
                  label: 'Montant',
                  value: '${order.totalAmount.toStringAsFixed(0)}\$',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusInfo extends StatelessWidget {
  final String label;
  final String value;

  const _StatusInfo({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Colors.white.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

class _UrgentBanner extends StatelessWidget {
  final int daysUntil;

  const _UrgentBanner({required this.daysUntil});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _P.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _P.red.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _P.red,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Commande urgente !',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: _P.red,
                  ),
                ),
                Text(
                  daysUntil == 0
                      ? 'L\'événement est aujourd\'hui'
                      : daysUntil == 1
                          ? 'L\'événement est demain'
                          : 'L\'événement est dans $daysUntil jours',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: _P.ink,
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

class _ClientInfoCard extends StatelessWidget {
  final WeddingOrder order;

  const _ClientInfoCard({required this.order});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _P.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _P.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _P.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.person_rounded, color: _P.blue, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Informations client',
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: _P.ink),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _InfoRow(
            icon: Icons.person_outline_rounded,
            label: 'Nom',
            value: order.clientName,
          ),
          const SizedBox(height: 12),
          _InfoRow(
            icon: Icons.email_outlined,
            label: 'Email',
            value: order.clientEmail,
          ),
          if (order.clientPhone != null) ...[
            const SizedBox(height: 12),
            _InfoRow(
              icon: Icons.phone_outlined,
              label: 'Téléphone',
              value: order.clientPhone!,
            ),
          ],
        ],
      ),
    );
  }
}

class _OrderInfoCard extends StatelessWidget {
  final WeddingOrder order;

  const _OrderInfoCard({required this.order});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _P.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _P.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _P.amber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.event_rounded, color: _P.amber, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Détails événement',
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: _P.ink),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _InfoRow(
            icon: Icons.calendar_today_rounded,
            label: 'Date',
            value: DateFormat('EEEE dd MMMM yyyy', 'fr_FR').format(order.eventDate),
          ),
          const SizedBox(height: 12),
          _InfoRow(
            icon: Icons.access_time_rounded,
            label: 'Heure',
            value: DateFormat('HH:mm').format(order.eventDate),
          ),
          if (order.eventLocation != null) ...[
            const SizedBox(height: 12),
            _InfoRow(
              icon: Icons.location_on_rounded,
              label: 'Lieu',
              value: order.eventLocation!,
            ),
          ],
          const SizedBox(height: 12),
          _InfoRow(
            icon: Icons.priority_high_rounded,
            label: 'Priorité',
            value: order.priorityDisplayName,
            valueColor: order.priority.color,
          ),
        ],
      ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  final WeddingOrder order;
  final VoidCallback onUpdatePayment;

  const _PaymentCard({
    required this.order,
    required this.onUpdatePayment,
  });

  @override
  Widget build(BuildContext context) {
    final paymentProgress = order.paymentProgress;
    final remaining = order.remainingAmount;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _P.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _P.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _P.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.payment_rounded, color: _P.green, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Paiement',
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: _P.ink),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: order.paymentStatus == PaymentStatus.paid
                      ? _P.green.withOpacity(0.1)
                      : order.paymentStatus == PaymentStatus.partial
                          ? _P.amber.withOpacity(0.1)
                          : _P.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  order.paymentStatusDisplayName,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: order.paymentStatus == PaymentStatus.paid
                        ? _P.green
                        : order.paymentStatus == PaymentStatus.partial
                            ? _P.amber
                            : _P.red,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Montants
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Montant total',
                    style: GoogleFonts.inter(fontSize: 11, color: _P.inkSoft),
                  ),
                  Text(
                    '${order.totalAmount.toStringAsFixed(0)}\$',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: _P.ink,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Payé',
                    style: GoogleFonts.inter(fontSize: 11, color: _P.inkSoft),
                  ),
                  Text(
                    '${(order.paidAmount ?? 0).toStringAsFixed(0)}\$',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: _P.green,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Barre de progression
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: paymentProgress,
              backgroundColor: _P.line,
              valueColor: AlwaysStoppedAnimation<Color>(
                paymentProgress >= 1 ? _P.green : _P.amber,
              ),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${(paymentProgress * 100).toStringAsFixed(0)}% payé',
            style: GoogleFonts.inter(fontSize: 11, color: _P.inkSoft),
          ),

          if (remaining > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _P.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 16, color: _P.amber),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Reste à payer: ${remaining.toStringAsFixed(0)}\$',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _P.amber,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onUpdatePayment,
              icon: const Icon(Icons.edit_rounded, size: 16),
              label: const Text('Mettre à jour'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _P.green,
                side: const BorderSide(color: _P.green),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TraiteurMenuCard extends StatelessWidget {
  final WeddingOrder order;
  final VoidCallback onOpenMenu;

  const _TraiteurMenuCard({
    required this.order,
    required this.onOpenMenu,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _P.amber.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _P.amber.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _P.amber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.restaurant_menu_rounded, color: _P.amber, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Menu traiteur',
                      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: _P.ink),
                    ),
                    Text(
                      order.menuValidated ? 'Menu validé' : 'En attente de validation',
                      style: GoogleFonts.inter(fontSize: 11, color: _P.inkSoft),
                    ),
                  ],
                ),
              ),
              if (order.menuValidated)
                const Icon(Icons.check_circle_rounded, color: _P.green, size: 24),
            ],
          ),
          const SizedBox(height: 12),
          if (order.menuPublic)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _P.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.public_rounded, size: 16, color: _P.green),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Menu public - Les invités peuvent voter',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _P.green,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onOpenMenu,
              icon: const Icon(Icons.restaurant_rounded, size: 18),
              label: const Text('Gérer le menu'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _P.amber,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpecificDataCard extends StatelessWidget {
  final WeddingOrder order;

  const _SpecificDataCard({required this.order});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _P.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _P.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _P.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.tune_rounded, color: _P.purple, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Détails de la commande',
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: _P.ink),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...order.orderData.entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    entry.key.replaceAll('_', ' '),
                    style: GoogleFonts.inter(fontSize: 13, color: _P.inkSoft),
                  ),
                  Text(
                    entry.value.toString(),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _P.ink,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _NotesCard extends StatelessWidget {
  final String notes;

  const _NotesCard({required this.notes});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _P.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _P.line),
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
                child: const Icon(Icons.note_rounded, color: _P.rose, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Notes',
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: _P.ink),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            notes,
            style: GoogleFonts.inter(fontSize: 13, color: _P.ink, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _TimelineCard extends StatelessWidget {
  final WeddingOrder order;

  const _TimelineCard({required this.order});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _P.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _P.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _P.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.history_rounded, color: _P.blue, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Historique',
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: _P.ink),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (order.timeline.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Aucune activité pour le moment',
                  style: GoogleFonts.inter(fontSize: 12, color: _P.inkSoft),
                ),
              ),
            )
          else
            ...order.timeline.reversed.map((event) {
              final isFirst = event == order.timeline.last;
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: isFirst ? _P.green : _P.line,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isFirst ? _P.green : _P.inkSoft,
                              width: 2,
                            ),
                          ),
                        ),
                        if (event != order.timeline.first)
                          Container(
                            width: 2,
                            height: 30,
                            color: _P.line,
                          ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            event.action,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _P.ink,
                            ),
                          ),
                          if (event.notes != null)
                            Text(
                              event.notes!,
                              style: GoogleFonts.inter(fontSize: 12, color: _P.inkSoft),
                            ),
                          const SizedBox(height: 4),
                          Text(
                            '${event.performedBy} • ${DateFormat('dd MMM yyyy HH:mm', 'fr_FR').format(event.timestamp)}',
                            style: GoogleFonts.inter(fontSize: 11, color: _P.inkSoft),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _ActionsCard extends StatelessWidget {
  final WeddingOrder order;
  final Function(OrderStatus) onUpdateStatus;

  const _ActionsCard({
    required this.order,
    required this.onUpdateStatus,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _P.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _P.line),
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
                child: const Icon(Icons.bolt_rounded, color: _P.rose, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Actions',
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: _P.ink),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Bouton prochain statut
          if (order.nextStatus != null)
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () => onUpdateStatus(order.nextStatus!),
                icon: Icon(order.nextStatus!.icon, size: 20),
                label: Text(order.nextActionLabel ?? 'Action suivante'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: order.nextStatus!.color,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800),
                ),
              ),
            ),

          if (order.nextStatus != null && order.status != OrderStatus.cancelled)
            const SizedBox(height: 12),

          // Bouton annuler
          if (order.status != OrderStatus.completed && order.status != OrderStatus.cancelled)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () => onUpdateStatus(OrderStatus.cancelled),
                icon: const Icon(Icons.cancel_rounded, size: 18),
                label: const Text('Annuler la commande'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _P.red,
                  side: const BorderSide(color: _P.red),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: _P.inkSoft),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 13, color: _P.inkSoft),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: valueColor ?? _P.ink,
            ),
          ),
        ),
      ],
    );
  }
}

extension OrderPriorityExtension on OrderPriority {
  Color get color {
    switch (this) {
      case OrderPriority.low:
        return Colors.grey;
      case OrderPriority.normal:
        return Colors.blue;
      case OrderPriority.high:
        return Colors.orange;
      case OrderPriority.urgent:
        return Colors.red;
    }
  }
}

extension OrderStatusColorExtension on OrderStatus {
  Color get color {
    switch (this) {
      case OrderStatus.pending:
        return const Color(0xFFF59E0B);
      case OrderStatus.confirmed:
        return const Color(0xFF3B82F6);
      case OrderStatus.inProgress:
        return const Color(0xFFF59E0B);
      case OrderStatus.ready:
        return const Color(0xFF10B981);
      case OrderStatus.delivered:
        return const Color(0xFF14B8A6);
      case OrderStatus.completed:
        return const Color(0xFF059669);
      case OrderStatus.cancelled:
        return const Color(0xFFEF4444);
    }
  }

  IconData get icon {
    switch (this) {
      case OrderStatus.pending:
        return Icons.hourglass_empty_rounded;
      case OrderStatus.confirmed:
        return Icons.check_circle_outline_rounded;
      case OrderStatus.inProgress:
        return Icons.sync_rounded;
      case OrderStatus.ready:
        return Icons.check_circle_rounded;
      case OrderStatus.delivered:
        return Icons.local_shipping_rounded;
      case OrderStatus.completed:
        return Icons.verified_rounded;
      case OrderStatus.cancelled:
        return Icons.cancel_rounded;
    }
  }

  String get displayName {
    switch (this) {
      case OrderStatus.pending:
        return 'En attente';
      case OrderStatus.confirmed:
        return 'Confirmée';
      case OrderStatus.inProgress:
        return 'En cours';
      case OrderStatus.ready:
        return 'Prête';
      case OrderStatus.delivered:
        return 'Livrée';
      case OrderStatus.completed:
        return 'Terminée';
      case OrderStatus.cancelled:
        return 'Annulée';
    }
  }
}
