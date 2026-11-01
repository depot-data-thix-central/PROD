// lib/presentation/thix_weeding/pages/staff/cadeaux/gifts_management_page.dart
// Staff : nom, photo, nature, déposant, statuts
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _R {
  static const rose = Color(0xFFE31C4E);
  static const green = Color(0xFF059669);
  static const amber = Color(0xFFD97706);
  static const blue = Color(0xFF0B3B8F);
  static const soft = Color(0xFF6B7280);
  static const border = Color(0xFFE5E7EB);
  static const surface = Color(0xFFF8FAFC);
  static const ink = Color(0xFF111827);
}

final _staffGiftsProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, weddingId) async {
  final res = await Supabase.instance.client
      .from('thix_weeding_gifts')
      .select()
      .eq('wedding_id', weddingId)
      .order('created_at', ascending: false);
  // Masquer collectes de groupe EN COURS
  return List<Map<String, dynamic>>.from(res)
      .where((e) => (e['status'] as String?) != 'group_active')
      .toList();
});

class GiftsManagementPage extends ConsumerWidget {
  final String weddingId;
  const GiftsManagementPage({super.key, required this.weddingId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_staffGiftsProvider(weddingId));

    return Scaffold(
      backgroundColor: _R.surface,
      appBar: AppBar(
        title: Text('Cadeaux', style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.white,
        foregroundColor: _R.ink,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () => ref.invalidate(_staffGiftsProvider(weddingId)),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur: $e')),
        data: (items) {
          final proposed = items.where((e) => e['status'] == 'proposed').toList();
          final approved = items.where((e) => e['status'] == 'approved' || e['status'] == 'wishlist').toList();
          final rejected = items.where((e) => e['status'] == 'rejected').toList();
          final done = items.where((e) => e['status'] == 'completed').toList();

          if (items.isEmpty) {
            return Center(
              child: Text(
                'Aucun cadeau signalé\n(les collectes de groupe en cours sont masquées)',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: _R.soft),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(_staffGiftsProvider(weddingId)),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (proposed.isNotEmpty) ...[
                  _sectionTitle('En attente de validation', proposed.length, _R.amber),
                  const SizedBox(height: 10),
                  ...proposed.map((g) => _GiftCard(
                        gift: g,
                        showActions: true,
                        onApprove: () => _set(ref, context, g['id'], 'approved'),
                        onReject: () => _set(ref, context, g['id'], 'rejected'),
                      )),
                  const SizedBox(height: 20),
                ],
                if (approved.isNotEmpty) ...[
                  _sectionTitle('Acceptés / catalogue', approved.length, _R.green),
                  const SizedBox(height: 10),
                  ...approved.map((g) => _GiftCard(gift: g)),
                  const SizedBox(height: 20),
                ],
                if (done.isNotEmpty) ...[
                  _sectionTitle('Déposés / complétés', done.length, _R.blue),
                  const SizedBox(height: 10),
                  ...done.map((g) => _GiftCard(gift: g)),
                  const SizedBox(height: 20),
                ],
                if (rejected.isNotEmpty) ...[
                  _sectionTitle('Rejetés', rejected.length, _R.rose),
                  const SizedBox(height: 10),
                  ...rejected.map((g) => _GiftCard(gift: g)),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _sectionTitle(String t, int n, Color c) => Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: c, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text('$t ($n)', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 15)),
        ],
      );

  Future<void> _set(WidgetRef ref, BuildContext context, String id, String status) async {
    try {
      await Supabase.instance.client.from('thix_weeding_gifts').update({'status': status}).eq('id', id);
      ref.invalidate(_staffGiftsProvider(weddingId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(status == 'approved' ? 'Cadeau accepté' : 'Cadeau rejeté'),
          backgroundColor: status == 'approved' ? _R.green : _R.rose,
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: _R.rose));
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
    final type = gift['gift_type'] as String? ?? '';
    final price = (gift['price'] as num?)?.toDouble() ?? 0;
    final status = gift['status'] as String? ?? '';
    final by = gift['proposed_by_name'] as String? ?? '';
    final img = gift['image_url'] as String? ?? '';
    final created = DateTime.tryParse('${gift['created_at'] ?? ''}');

    final (statusLabel, statusColor) = switch (status) {
      'proposed' => ('En attente', _R.amber),
      'approved' || 'wishlist' => (status == 'wishlist' ? 'Catalogue' : 'Accepté', _R.green),
      'rejected' => ('Rejeté', _R.rose),
      'completed' => ('Déposé', _R.blue),
      _ => (status, _R.soft),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _R.border),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3)),
        ],
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
                    ? Image.network(
                        img,
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _ph(),
                      )
                    : _ph(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 15),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            statusLabel,
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (type.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        type,
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: _R.blue),
                      ),
                    ],
                    if (desc.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        desc,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(fontSize: 12, color: _R.soft),
                      ),
                    ],
                    if (price > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${price.toStringAsFixed(0)} FCFA',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: _R.rose),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _R.surface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.person_outline, size: 16, color: _R.soft),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    by.isNotEmpty ? 'Signalé par $by' : 'Signalé (anonyme)',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
                if (created != null)
                  Text(
                    '${created.day.toString().padLeft(2, '0')}/${created.month.toString().padLeft(2, '0')}',
                    style: GoogleFonts.inter(fontSize: 11, color: _R.soft),
                  ),
              ],
            ),
          ),
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
        width: 72,
        height: 72,
        color: const Color(0xFFFFE3EA),
        child: const Icon(Icons.card_giftcard, color: _R.rose),
      );
}
