// lib/presentation/thix_weeding/pages/guest/cadeaux_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _R {
  static const rose = Color(0xFFE31C4E);
  static const roseSoft = Color(0xFFFFE3EA);
  static const green = Color(0xFF059669);
  static const amber = Color(0xFFD97706);
  static const ink = Color(0xFF241521);
  static const soft = Color(0xFF8A7580);
  static const border = Color(0xFFF3E1E6);
  static const surface = Color(0xFFFFFBFC);
}

final _guestGiftsProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, weddingId) async {
  final res = await Supabase.instance.client
      .from('thix_weeding_gifts')
      .select()
      .eq('wedding_id', weddingId)
      .order('created_at', ascending: false);
  return List<Map<String, dynamic>>.from(res)
      .where((e) => (e['status'] as String?) != 'rejected')
      .toList();
});

class CadeauxPage extends ConsumerStatefulWidget {
  final String weddingId;
  const CadeauxPage({super.key, required this.weddingId});

  @override
  ConsumerState<CadeauxPage> createState() => _CadeauxPageState();
}

class _CadeauxPageState extends ConsumerState<CadeauxPage> {
  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_guestGiftsProvider(widget.weddingId));

    return Scaffold(
      backgroundColor: _R.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _R.ink,
        elevation: 0,
        title: Text('Cadeaux', style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _R.rose,
        onPressed: () => _openPropose(asGroup: false),
        icon: const Icon(Icons.add),
        label: const Text('Proposer un cadeau'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator(color: _R.rose)),
        error: (e, _) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Erreur: $e'),
            FilledButton(
              onPressed: () => ref.invalidate(_guestGiftsProvider(widget.weddingId)),
              child: const Text('Réessayer'),
            ),
          ]),
        ),
        data: (gifts) => RefreshIndicator(
          color: _R.rose,
          onRefresh: () async => ref.invalidate(_guestGiftsProvider(widget.weddingId)),
          child: CustomScrollView(slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Offrez un présent à votre manière',
                        style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 6),
                    Text(
                      'Contribuez, proposez un cadeau, ou lancez une collecte entre invités.',
                      style: GoogleFonts.inter(fontSize: 13, color: _R.soft),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => _openPropose(asGroup: true),
                      icon: const Icon(Icons.groups_outlined, size: 18),
                      label: const Text('Collecte de groupe'),
                      style: OutlinedButton.styleFrom(foregroundColor: _R.rose),
                    ),
                  ],
                ),
              ),
            ),
            if (gifts.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: Text('Aucun cadeau pour le moment')),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.72,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (_, i) {
                      final g = gifts[i];
                      return _Tile(gift: g, onTap: () => _contribute(g));
                    },
                    childCount: gifts.length,
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }

  Future<void> _openPropose({required bool asGroup}) async {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final whoCtrl = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(asGroup ? 'Collecte de groupe' : 'Proposer un cadeau',
                  style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nom du cadeau *', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: priceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Montant (FCFA) *', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: descCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: whoCtrl, decoration: const InputDecoration(labelText: 'Votre nom *', border: OutlineInputBorder())),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: _R.rose),
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    final price = double.tryParse(priceCtrl.text.replaceAll(' ', '')) ?? 0;
                    final who = whoCtrl.text.trim();
                    if (name.length < 2 || price <= 0 || who.length < 2) return;
                    try {
                      await Supabase.instance.client.from('thix_weeding_gifts').insert({
                        'wedding_id': widget.weddingId,
                        'name': name,
                        'description': descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                        'price': price,
                        'contributed': 0,
                        'status': asGroup ? 'group_active' : 'proposed',
                        'is_group_collect': asGroup,
                        'proposed_by_name': who,
                      });
                      ref.invalidate(_guestGiftsProvider(widget.weddingId));
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(asGroup ? 'Collecte lancée' : 'Proposition envoyée'),
                          backgroundColor: _R.green,
                        ));
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: _R.rose));
                    }
                  },
                  child: Text(asGroup ? 'Lancer la collecte' : 'Envoyer'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _contribute(Map<String, dynamic> gift) async {
    final status = gift['status'] as String? ?? '';
    if (status == 'proposed' || status == 'rejected') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('En attente de validation organisation')));
      return;
    }
    final amountCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(gift['name']?.toString() ?? 'Cadeau', style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 18)),
            const SizedBox(height: 12),
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Votre nom', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Montant FCFA', border: OutlineInputBorder())),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: _R.rose),
                onPressed: () async {
                  final amount = double.tryParse(amountCtrl.text.replaceAll(' ', '')) ?? 0;
                  final who = nameCtrl.text.trim();
                  if (amount <= 0 || who.length < 2) return;
                  try {
                    final id = gift['id'] as String;
                    await Supabase.instance.client.from('thix_weeding_gift_contributions').insert({
                      'gift_id': id,
                      'amount': amount,
                      'contributor_name': who,
                    });
                    final cur = (gift['contributed'] as num?)?.toDouble() ?? 0;
                    final price = (gift['price'] as num?)?.toDouble() ?? 0;
                    final next = cur + amount;
                    final patch = <String, dynamic>{'contributed': next};
                    if (price > 0 && next >= price) {
                      patch['status'] = 'completed';
                      patch['is_reserved'] = true;
                    }
                    await Supabase.instance.client.from('thix_weeding_gifts').update(patch).eq('id', id);
                    ref.invalidate(_guestGiftsProvider(widget.weddingId));
                    if (ctx.mounted) Navigator.pop(ctx);
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
                  }
                },
                child: const Text('Contribuer'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final Map<String, dynamic> gift;
  final VoidCallback onTap;
  const _Tile({required this.gift, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = gift['name']?.toString() ?? '';
    final price = (gift['price'] as num?)?.toDouble() ?? 0;
    final contributed = (gift['contributed'] as num?)?.toDouble() ?? 0;
    final status = gift['status']?.toString() ?? '';
    final pct = price > 0 ? (contributed / price).clamp(0.0, 1.0) : 0.0;
    final img = gift['image_url']?.toString() ?? '';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: _R.border)),
          clipBehavior: Clip.antiAlias,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Stack(fit: StackFit.expand, children: [
                img.isNotEmpty
                    ? Image.network(img, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: _R.roseSoft, child: const Icon(Icons.card_giftcard, color: _R.rose)))
                    : Container(color: _R.roseSoft, child: const Icon(Icons.card_giftcard, color: _R.rose, size: 36)),
                if (status == 'group_active')
                  Positioned(top: 8, left: 8, child: _badge('Groupe', _R.green)),
                if (status == 'proposed')
                  Positioned(top: 8, left: 8, child: _badge('Attente', _R.amber)),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13)),
                Text('${price.toStringAsFixed(0)} FCFA', style: GoogleFonts.inter(color: _R.rose, fontWeight: FontWeight.w800, fontSize: 12)),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(value: pct, minHeight: 5, backgroundColor: _R.border, color: _R.rose),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _badge(String t, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(8)),
        child: Text(t, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
      );
}
