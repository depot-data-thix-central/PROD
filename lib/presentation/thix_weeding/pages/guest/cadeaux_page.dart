// lib/presentation/thix_weeding/pages/guest/cadeaux_page.dart
// ============================================================================
// CADEAUX INVITÉ — catalogue + proposer + collecte de groupe
// ============================================================================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/presentation/thix_weeding/models/gift_model.dart';
import 'package:thix_id/presentation/thix_weeding/pages/staff/providers/thix_weeding_providers.dart';

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

class CadeauxPage extends ConsumerStatefulWidget {
  final String weddingId;
  const CadeauxPage({super.key, required this.weddingId});

  @override
  ConsumerState<CadeauxPage> createState() => _CadeauxPageState();
}

class _CadeauxPageState extends ConsumerState<CadeauxPage> {
  @override
  Widget build(BuildContext context) {
    final async = ref.watch(guestGiftsProvider(widget.weddingId));

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
        onPressed: () => _openProposeSheet(asGroup: false),
        icon: const Icon(Icons.add),
        label: const Text('Proposer un cadeau'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator(color: _R.rose)),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Erreur: $e'),
              FilledButton(
                onPressed: () => ref.invalidate(guestGiftsProvider(widget.weddingId)),
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
        data: (raw) {
          final gifts = raw.map(GiftItem.fromJson).toList();
          // Invité voit catalogue, approved, completed, group_active, et ses proposed
          final visible = gifts.where((g) => g.status != 'rejected').toList();

          return RefreshIndicator(
            color: _R.rose,
            onRefresh: () async => ref.invalidate(guestGiftsProvider(widget.weddingId)),
            child: CustomScrollView(
              slivers: [
                sliverPad(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Offrez un présent à votre manière',
                        style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: _R.ink),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Contribuez à un cadeau, proposez le vôtre, ou lancez une collecte entre invités.',
                        style: GoogleFonts.inter(fontSize: 13, color: _R.soft, height: 1.4),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _openProposeSheet(asGroup: true),
                              icon: const Icon(Icons.groups_outlined, size: 18),
                              label: const Text('Collecte de groupe'),
                              style: OutlinedButton.styleFrom(foregroundColor: _R.rose),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (visible.isEmpty)
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
                        childAspectRatio: 0.68,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (_, i) {
                          final g = visible[i];
                          return _GiftTile(
                            gift: g,
                            onTap: () => _openGiftActions(g),
                          );
                        },
                        childCount: visible.length,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget sliverPad({required Widget child}) => SliverToBoxAdapter(
        child: Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 8), child: child),
      );

  Future<void> _openProposeSheet({required bool asGroup}) async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final proposerCtrl = TextEditingController();

    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final g = await Supabase.instance.client
          .from('thix_weeding_guests')
          .select('id, name')
          .eq('wedding_id', widget.weddingId)
          .eq('user_id', user.id)
          .maybeSingle();
      if (g != null) proposerCtrl.text = (g['name'] as String?) ?? '';
    }

    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  asGroup ? 'Lancer une collecte de groupe' : 'Proposer un cadeau',
                  style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                Text(
                  asGroup
                      ? 'Les autres invités pourront contribuer. L’organisation ne voit pas la collecte tant qu’elle est en cours.'
                      : 'L’organisation validera ou refusera votre proposition.',
                  style: GoogleFonts.inter(fontSize: 12, color: _R.soft),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nom du cadeau *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: priceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Montant cible (FCFA) *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Description (optionnel)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: proposerCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Votre nom *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: _R.rose),
                    onPressed: () async {
                      final name = nameCtrl.text.trim();
                      final price = double.tryParse(priceCtrl.text.replaceAll(' ', '')) ?? 0;
                      final who = proposerCtrl.text.trim();
                      if (name.length < 2 || price <= 0 || who.length < 2) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Nom, montant et votre nom sont requis'),
                        ));
                        return;
                      }
                      try {
                        String? guestId;
                        final user = Supabase.instance.client.auth.currentUser;
                        if (user != null) {
                          final g = await Supabase.instance.client
                              .from('thix_weeding_guests')
                              .select('id')
                              .eq('wedding_id', widget.weddingId)
                              .eq('user_id', user.id)
                              .maybeSingle();
                          guestId = g?['id'] as String?;
                        }
                        await ref.read(giftServiceProvider).propose(
                              weddingId: widget.weddingId,
                              name: name,
                              description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                              price: price,
                              guestId: guestId,
                              guestName: who,
                              asGroup: asGroup,
                            );
                        ref.invalidate(guestGiftsProvider(widget.weddingId));
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(asGroup
                                ? 'Collecte lancée — invitez d’autres invités à contribuer'
                                : 'Proposition envoyée à l’organisation'),
                            backgroundColor: _R.green,
                          ));
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('Erreur: $e'),
                          backgroundColor: _R.rose,
                        ));
                      }
                    },
                    child: Text(asGroup ? 'Lancer la collecte' : 'Envoyer la proposition'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openGiftActions(GiftItem gift) async {
    final amountCtrl = TextEditingController();
    final nameCtrl = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(gift.name, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text(
                '${gift.price.toStringAsFixed(0)} FCFA — restant ${gift.remaining.toStringAsFixed(0)}',
                style: GoogleFonts.inter(color: _R.rose, fontWeight: FontWeight.w700),
              ),
              if (gift.status == 'proposed')
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('En attente de validation par l’organisation',
                      style: GoogleFonts.inter(fontSize: 12, color: _R.amber)),
                ),
              if (gift.isGroupActive)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('Collecte de groupe en cours',
                      style: GoogleFonts.inter(fontSize: 12, color: _R.green, fontWeight: FontWeight.w700)),
                ),
              const SizedBox(height: 14),
              if (!gift.isCompleted && gift.status != 'proposed' && gift.status != 'rejected') ...[
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Votre nom', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Montant (FCFA)', border: OutlineInputBorder()),
                ),
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
                        await ref.read(giftServiceProvider).contribute(
                              giftId: gift.id,
                              amount: amount,
                              contributorName: who,
                            );
                        ref.invalidate(guestGiftsProvider(widget.weddingId));
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text('Contribution enregistrée — merci !'),
                            backgroundColor: _R.green,
                          ));
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
                      }
                    },
                    child: const Text('Contribuer'),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _GiftTile extends StatelessWidget {
  final GiftItem gift;
  final VoidCallback onTap;
  const _GiftTile({required this.gift, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _R.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    gift.imageUrl.isNotEmpty
                        ? Image.network(gift.imageUrl, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                                  color: _R.roseSoft,
                                  child: const Icon(Icons.card_giftcard, color: _R.rose),
                                ))
                        : Container(
                            color: _R.roseSoft,
                            child: const Icon(Icons.card_giftcard, color: _R.rose, size: 36),
                          ),
                    if (gift.isGroupActive)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: _badge('Groupe', _R.green),
                      ),
                    if (gift.status == 'proposed')
                      Positioned(
                        top: 8,
                        left: 8,
                        child: _badge('En attente', _R.amber),
                      ),
                    if (gift.isCompleted)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: _badge('Complet', _R.green),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(gift.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text('${gift.price.toStringAsFixed(0)} FCFA',
                        style: GoogleFonts.inter(color: _R.rose, fontWeight: FontWeight.w800, fontSize: 12)),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: gift.percent,
                        minHeight: 5,
                        backgroundColor: _R.border,
                        color: _R.rose,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('${(gift.percent * 100).toStringAsFixed(0)}% contribué',
                        style: GoogleFonts.inter(fontSize: 10, color: _R.soft)),
                  ],
                ),
              ),
            ],
          ),
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
