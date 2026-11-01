// lib/presentation/thix_weeding/pages/staff/cadeaux/gifts_management_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:thix_id/presentation/thix_weeding/pages/staff/providers/thix_weeding_providers.dart';

class _R {
  static const rose = Color(0xFFE31C4E);
  static const green = Color(0xFF059669);
  static const amber = Color(0xFFD97706);
  static const blue = Color(0xFF0B3B8F);
  static const ink = Color(0xFF111827);
  static const soft = Color(0xFF6B7280);
  static const border = Color(0xFFE5E7EB);
  static const surface = Color(0xFFF8FAFC);
}

/// Staff: voir propositions, accepter / rejeter.
/// Les collectes de groupe EN COURS ne sont PAS listées (hideGroupActive).
class GiftsManagementPage extends ConsumerWidget {
  final String weddingId;
  const GiftsManagementPage({super.key, required this.weddingId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(staffGiftsProvider(weddingId));

    return Scaffold(
      backgroundColor: _R.surface,
      appBar: AppBar(
        title: Text('Cadeaux', style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.white,
        foregroundColor: _R.ink,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Rafraîchir',
            onPressed: () => ref.invalidate(staffGiftsProvider(weddingId)),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur: $e')),
        data: (items) {
          final proposed = items.where((e) => e['status'] == 'proposed').toList();
          final others = items.where((e) => e['status'] != 'proposed').toList();

          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.card_giftcard_outlined, size: 48, color: _R.soft),
                  const SizedBox(height: 12),
                  Text('Aucun cadeau', style: GoogleFonts.inter(color: _R.soft)),
                  const SizedBox(height: 4),
                  Text(
                    'Les collectes de groupe en cours sont masquées ici',
                    style: GoogleFonts.inter(fontSize: 12, color: _R.soft),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(staffGiftsProvider(weddingId)),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (proposed.isNotEmpty) ...[
                  Text(
                    'Propositions à valider (${proposed.length})',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                  const SizedBox(height: 10),
                  ...proposed.map((g) => _GiftCard(
                        gift: g,
                        showActions: true,
                        onApprove: () => _setStatus(ref, context, g['id'], 'approved'),
                        onReject: () => _setStatus(ref, context, g['id'], 'rejected'),
                      )),
                  const SizedBox(height: 20),
                ],
                Text(
                  'Catalogue & validés',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 15),
                ),
                const SizedBox(height: 10),
                if (others.isEmpty)
                  Text('Aucun autre cadeau', style: GoogleFonts.inter(color: _R.soft))
                else
                  ...others.map((g) => _GiftCard(gift: g)),
                const SizedBox(height: 12),
                Text(
                  'Note : les cadeaux en collecte de groupe active ne s’affichent pas ici.',
                  style: GoogleFonts.inter(fontSize: 11, color: _R.soft, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _setStatus(WidgetRef ref, BuildContext context, String id, String status) async {
    try {
      await ref.read(giftServiceProvider).setStatus(id, status);
      ref.invalidate(staffGiftsProvider(weddingId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(status == 'approved' ? 'Cadeau accepté' : 'Cadeau rejeté'),
          backgroundColor: status == 'approved' ? _R.green : _R.rose,
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: _R.rose));
      }
    }
  }
}

class _GiftCard extends StatelessWidget {
  final Map<String, dynamic> gift;
  final bool showActions;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  const _GiftCard({
    required this.gift,
    this.showActions = false,
    this.onApprove,
    this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final name = gift['name'] as String? ?? '';
    final desc = gift['description'] as String? ?? '';
    final price = (gift['price'] as num?)?.toDouble() ?? 0;
    final contributed = (gift['contributed'] as num?)?.toDouble() ?? 0;
    final status = gift['status'] as String? ?? '';
    final by = gift['proposed_by_name'] as String?;
    final img = gift['image_url'] as String? ?? '';
    final pct = price > 0 ? (contributed / price).clamp(0.0, 1.0) : 0.0;

    Color statusColor;
    String statusLabel;
    switch (status) {
      case 'proposed':
        statusColor = _R.amber;
        statusLabel = 'En attente';
        break;
      case 'approved':
      case 'wishlist':
        statusColor = _R.green;
        statusLabel = status == 'wishlist' ? 'Catalogue' : 'Accepté';
        break;
      case 'rejected':
        statusColor = _R.rose;
        statusLabel = 'Rejeté';
        break;
      case 'completed':
        statusColor = _R.blue;
        statusLabel = 'Complété';
        break;
      default:
        statusColor = _R.soft;
        statusLabel = status;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _R.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: img.isNotEmpty
                    ? Image.network(img, width: 64, height: 64, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _ph())
                    : _ph(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 14)),
                    if (desc.isNotEmpty)
                      Text(desc, maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(fontSize: 12, color: _R.soft)),
                    const SizedBox(height: 4),
                    Text('${price.toStringAsFixed(0)} FCFA',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: _R.rose)),
                    if (by != null && by.isNotEmpty)
                      Text('Proposé par $by', style: GoogleFonts.inter(fontSize: 11, color: _R.soft)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(statusLabel,
                    style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: statusColor)),
              ),
            ],
          ),
          if (contributed > 0) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 6,
                backgroundColor: _R.border,
                color: _R.green,
              ),
            ),
            const SizedBox(height: 4),
            Text('${contributed.toStringAsFixed(0)} / ${price.toStringAsFixed(0)} FCFA',
                style: GoogleFonts.inter(fontSize: 11, color: _R.soft)),
          ],
          if (showActions) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onReject,
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Rejeter'),
                    style: OutlinedButton.styleFrom(foregroundColor: _R.rose),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onApprove,
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Accepter'),
                    style: FilledButton.styleFrom(backgroundColor: _R.green),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _ph() => Container(
        width: 64,
        height: 64,
        color: _R.border,
        child: const Icon(Icons.card_giftcard, color: _R.soft),
      );
}
