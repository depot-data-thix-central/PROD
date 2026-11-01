// lib/presentation/thix_weeding/pages/staff/cadeaux/gifts_management_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _R {
  static const rose = Color(0xFFE31C4E);
  static const green = Color(0xFF059669);
  static const amber = Color(0xFFD97706);
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
  return List<Map<String, dynamic>>.from(res).where((e) {
    final st = e['status'] as String? ?? '';
    return st != 'group_active';
  }).toList();
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
          final others = items.where((e) => e['status'] != 'proposed').toList();
          if (items.isEmpty) {
            return Center(child: Text('Aucun cadeau\n(les collectes de groupe en cours sont masquées)',
                textAlign: TextAlign.center, style: GoogleFonts.inter(color: _R.soft)));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(_staffGiftsProvider(weddingId)),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (proposed.isNotEmpty) ...[
                  Text('Propositions (${proposed.length})', style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  ...proposed.map((g) => _Card(
                        gift: g,
                        actions: true,
                        onApprove: () => _set(ref, context, g['id'], 'approved'),
                        onReject: () => _set(ref, context, g['id'], 'rejected'),
                      )),
                  const SizedBox(height: 16),
                ],
                Text('Catalogue & validés', style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                ...others.map((g) => _Card(gift: g)),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _set(WidgetRef ref, BuildContext context, String id, String status) async {
    try {
      await Supabase.instance.client.from('thix_weeding_gifts').update({'status': status}).eq('id', id);
      ref.invalidate(_staffGiftsProvider(weddingId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(status == 'approved' ? 'Accepté' : 'Rejeté'),
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

class _Card extends StatelessWidget {
  final Map<String, dynamic> gift;
  final bool actions;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  const _Card({required this.gift, this.actions = false, this.onApprove, this.onReject});

  @override
  Widget build(BuildContext context) {
    final name = gift['name']?.toString() ?? '';
    final price = (gift['price'] as num?)?.toDouble() ?? 0;
    final status = gift['status']?.toString() ?? '';
    final by = gift['proposed_by_name']?.toString();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: _R.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(name, style: GoogleFonts.inter(fontWeight: FontWeight.w800))),
          Text(status, style: GoogleFonts.inter(fontSize: 11, color: _R.soft)),
        ]),
        Text('${price.toStringAsFixed(0)} FCFA', style: GoogleFonts.inter(color: _R.rose, fontWeight: FontWeight.w800)),
        if (by != null && by.isNotEmpty) Text('Par $by', style: GoogleFonts.inter(fontSize: 12, color: _R.soft)),
        if (actions) ...[
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: onReject, child: const Text('Rejeter'))),
            const SizedBox(width: 8),
            Expanded(child: FilledButton(onPressed: onApprove, style: FilledButton.styleFrom(backgroundColor: _R.green), child: const Text('Accepter'))),
          ]),
        ],
      ]),
    );
  }
}
