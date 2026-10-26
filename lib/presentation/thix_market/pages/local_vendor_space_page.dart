
// ============================================================================
// ESPACE PRODUCTEUR & MODÉRATION
//  • Producteur : crée ses produits locaux (toujours PENDING) + suit ses statuts
//  • Modérateur/Admin : file de validation, produit de la semaine,
//    cartes du portail, commandes locales (routées vers lui)
//  • Sans shop : carte « Devenir coopérative »
// ============================================================================
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/drc_portal_theme.dart';
import '../core/local_sectors.dart';
import '../providers/local_moderation_providers.dart';

class LocalVendorSpacePage extends ConsumerWidget {
  const LocalVendorSpacePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMod = ref.watch(localIsModeratorProvider).valueOrNull ?? false;
    final shop = ref.watch(localMyShopProvider).valueOrNull;

    return Scaffold(
      backgroundColor: kDrcBg,
      appBar: AppBar(
        backgroundColor: kDrcBlueDeep,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded, color: Colors.white), onPressed: () => context.pop()),
        title: const Text('Espace producteur & modération', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
      ),
      floatingActionButton: shop != null
          ? FloatingActionButton.extended(
              onPressed: () => _openProductForm(context, ref, shop['id'].toString()),
              backgroundColor: kDrcBlue,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Nouveau produit', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
        children: [
          // ── PRODUCTEUR ──
          if (shop != null) ...[
            _header('Mes produits locaux', Icons.agriculture_rounded),
            const SizedBox(height: 10),
            _MyProductsSection(shopId: shop['id'].toString()),
            const SizedBox(height: 24),
          ],
          if (shop == null && !isMod) ...[
            _BecomeCooperativeCard(),
            const SizedBox(height: 24),
          ],
          // ── MODÉRATEUR / ADMIN ──
          if (isMod) ...[
            _header('File de validation', Icons.fact_check_rounded),
            const SizedBox(height: 10),
            const _ValidationQueueSection(),
            const SizedBox(height: 24),
            _header('Produit de la semaine', Icons.star_rounded),
            const SizedBox(height: 10),
            const _WeeklySection(),
            const SizedBox(height: 24),
            _header('Cartes du portail', Icons.style_rounded),
            const SizedBox(height: 10),
            const _PortalCardsSection(),
            const SizedBox(height: 24),
            _header('Commandes locales', Icons.local_shipping_rounded),
            const SizedBox(height: 10),
            const _ModeratorOrdersSection(),
          ],
        ],
      ),
    );
  }

  Widget _header(String t, IconData icon) => Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(color: kDrcBlue.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 16, color: kDrcBlue),
          ),
          const SizedBox(width: 8),
          Text(t, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: kDrcInk)),
        ],
      );

  void _openProductForm(BuildContext context, WidgetRef ref, String shopId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ProductFormSheet(shopId: shopId),
    );
  }
}

// ============================================================================
// MES PRODUITS (producteur)
// ============================================================================
class _MyProductsSection extends ConsumerWidget {
  final String shopId;
  const _MyProductsSection({required this.shopId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myLocalProductsProvider(shopId));
    return async.when(
      loading: () => const SizedBox(height: 60, child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: kDrcBlue))),
      error: (_, __) => const Text('Erreur de chargement'),
      data: (list) {
        if (list.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: kDrcLine)),
            child: const Text('Aucun produit local. Créez votre premier produit : il sera visible après validation par un modérateur.',
                style: TextStyle(fontSize: 12, color: kDrcSub)),
          );
        }
        return Column(
          children: list.map((p) {
            final status = p['status']?.toString() ?? 'pending';
            final color = status == 'active' ? kDrcBlue : status == 'rejected' ? kDrcRed : kDrcYellow;
            final label = status == 'active' ? 'Approuvé' : status == 'rejected' ? 'Refusé' : 'En attente';
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: kDrcLine)),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p['title']?.toString() ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: kDrcInk)),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                          child: Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: color)),
                        ),
                      ],
                    ),
                  ),
                  Text('${p['price'] ?? 0}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: kDrcBlueDeep)),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

// ============================================================================
// DEVENIR COOPÉRATIVE
// ============================================================================
class _BecomeCooperativeCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [kDrcBlueDeep, kDrcBlue]),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Vous êtes producteur local ?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
          const SizedBox(height: 6),
          Text(
            'Créez votre coopérative pour publier vos produits Made in Congo. Chaque produit est vérifié par un modérateur avant publication.',
            style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 11.5, height: 1.4),
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              onTap: () => showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => const _CooperativeFormSheet()),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                child: const Text('Créer ma coopérative', style: TextStyle(color: kDrcBlueDeep, fontWeight: FontWeight.w900, fontSize: 12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// FILE DE VALIDATION (modérateur)
// ============================================================================
class _ValidationQueueSection extends ConsumerWidget {
  const _ValidationQueueSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(pendingLocalProductsProvider);
    final busy = ref.watch(localModerationProvider).isLoading;
    return async.when(
      loading: () => const SizedBox(height: 60, child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: kDrcBlue))),
      error: (_, __) => const Text('Erreur'),
      data: (list) {
        if (list.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: kDrcLine)),
            child: const Text('Aucun produit en attente de validation. 🎉', style: TextStyle(fontSize: 12, color: kDrcSub)),
          );
        }
        return Column(
          children: list.map((p) {
            final id = p['id'].toString();
            final img = p['image_url']?.toString() ?? '';
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: kDrcLine)),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: kDrcSoft,
                      borderRadius: BorderRadius.circular(12),
                      image: img.startsWith('http') ? DecorationImage(image: CachedNetworkImageProvider(img), fit: BoxFit.cover) : null,
                    ),
                    child: img.startsWith('http') ? null : const Icon(Icons.inventory_2_outlined, color: kDrcSub, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p['title']?.toString() ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: kDrcInk)),
                        const SizedBox(height: 2),
                        Text(p['shop']?['name']?.toString() ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: kDrcSub)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    tooltip: 'Approuver',
                    onPressed: busy ? null : () => ref.read(localModerationProvider.notifier).approve(id),
                    icon: const Icon(Icons.check_circle_rounded, color: kDrcBlue, size: 22),
                  ),
                  IconButton(
                    tooltip: 'Refuser',
                    onPressed: busy ? null : () => _rejectDialog(context, ref, id),
                    icon: const Icon(Icons.cancel_rounded, color: kDrcRed, size: 22),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  void _rejectDialog(BuildContext context, WidgetRef ref, String id) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Motif du refus', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
        content: TextField(controller: ctrl, maxLines: 3, decoration: const InputDecoration(hintText: 'Expliquez au producteur...')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(localModerationProvider.notifier).reject(id, ctrl.text.trim());
            },
            child: const Text('Refuser', style: TextStyle(color: kDrcRed, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// PRODUIT DE LA SEMAINE (modérateur)
// ============================================================================
class _WeeklySection extends ConsumerWidget {
  const _WeeklySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(weeklyProductsProvider);
    return async.when(
      loading: () => const SizedBox(height: 50, child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: kDrcBlue))),
      error: (_, __) => const SizedBox.shrink(),
      data: (p) {
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: kDrcYellow.withOpacity(0.5))),
          child: Row(
            children: [
              Expanded(
                child: p == null
                    ? const Text('Aucun produit de la semaine sélectionné.', style: TextStyle(fontSize: 12, color: kDrcSub))
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p['title']?.toString() ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: kDrcInk)),
                          const SizedBox(height: 2),
                          Text(p['shop']?['name']?.toString() ?? '', style: const TextStyle(fontSize: 10.5, color: kDrcSub)),
                        ],
                      ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => showModalBottomSheet(context: context, backgroundColor: Colors.transparent, isScrollControlled: true, builder: (_) => const _WeeklyPickerSheet()),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: kDrcBlue, borderRadius: BorderRadius.circular(10)),
                  child: const Text('Choisir', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _WeeklyPickerSheet extends ConsumerWidget {
  const _WeeklyPickerSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(activeLocalProductsForModProvider);
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator(color: kDrcBlue)),
        error: (_, __) => const Center(child: Text('Erreur')),
        data: (list) => ListView(
          shrinkWrap: true,
          children: list.map((p) {
            return ListTile(
              onTap: () async {
                Navigator.pop(context);
                await ref.read(localModerationProvider.notifier).setWeekly(p['id'].toString());
              },
              leading: const Icon(Icons.star_outline_rounded, color: kDrcYellow),
              title: Text(p['title']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
              subtitle: Text(p['shop']?['name']?.toString() ?? '', style: const TextStyle(fontSize: 10.5)),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ============================================================================
// CARTES DU PORTAIL (modérateur)
// ============================================================================
class _PortalCardsSection extends ConsumerWidget {
  const _PortalCardsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(drcPortalHighlightsProvider);
    return Column(
      children: [
        async.when(
          loading: () => const SizedBox(height: 50, child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: kDrcBlue))),
          error: (_, __) => const SizedBox.shrink(),
          data: (items) => Column(
            children: items.map((h) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: kDrcLine)),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: h.color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                      child: Icon(portalHighlightIcon(h.icon), size: 16, color: h.color),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(h.titleFr, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: kDrcInk))),
                    IconButton(
                      icon: const Icon(Icons.edit_rounded, size: 18, color: kDrcBlue),
                      onPressed: () => showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => _HighlightFormSheet(existing: h)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 18, color: kDrcRed),
                      onPressed: () => ref.read(localModerationProvider.notifier).deleteHighlight(h.id),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: GestureDetector(
            onTap: () => showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => const _HighlightFormSheet()),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(color: kDrcBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: kDrcBlue.withOpacity(0.3))),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.add_rounded, size: 15, color: kDrcBlue),
                SizedBox(width: 6),
                Text('Ajouter une carte', style: TextStyle(color: kDrcBlue, fontWeight: FontWeight.w800, fontSize: 11.5)),
              ]),
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// COMMANDES LOCALES (modérateur)
// ============================================================================
class _ModeratorOrdersSection extends ConsumerWidget {
  const _ModeratorOrdersSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(moderatorLocalOrdersProvider);
    return async.when(
      loading: () => const SizedBox(height: 50, child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: kDrcBlue))),
      error: (_, __) => const SizedBox.shrink(),
      data: (orders) {
        if (orders.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: kDrcLine)),
            child: const Text('Aucune commande locale pour le moment.', style: TextStyle(fontSize: 12, color: kDrcSub)),
          );
        }
        return Column(
          children: orders.map((o) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: kDrcLine)),
              child: Row(
                children: [
                  const Icon(Icons.receipt_long_rounded, color: kDrcBlue, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Commande #${(o['id']?.toString() ?? '').substring(0, 6)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: kDrcInk)),
                        const SizedBox(height: 2),
                        Text('Statut : ${o['status'] ?? '—'}', style: const TextStyle(fontSize: 10.5, color: kDrcSub)),
                      ],
                    ),
                  ),
                  Text('${o['total_amount'] ?? o['total'] ?? 0}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: kDrcBlueDeep)),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

// ============================================================================
// SHEETS : FORMULAIRES
// ============================================================================
class _ProductFormSheet extends ConsumerStatefulWidget {
  final String shopId;
  const _ProductFormSheet({required this.shopId});
  @override
  ConsumerState<_ProductFormSheet> createState() => _ProductFormSheetState();
}

class _ProductFormSheetState extends ConsumerState<_ProductFormSheet> {
  final _title = TextEditingController();
  final _price = TextEditingController();
  final _stock = TextEditingController();
  final _desc = TextEditingController();
  String _sector = kLocalSectors.first.id;
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _price.dispose();
    _stock.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) return;
    setState(() => _busy = true);
    final err = await ref.read(localModerationProvider.notifier).createLocalProduct(
          shopId: widget.shopId,
          title: _title.text.trim(),
          price: double.tryParse(_price.text.replaceAll(',', '.')) ?? 0,
          sectorId: _sector,
          stock: int.tryParse(_stock.text) ?? 0,
          description: _desc.text.trim(),
        );
    if (!mounted) return;
    setState(() => _busy = false);
    if (err == null) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Produit soumis pour validation ✅'), backgroundColor: kDrcBlue));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err), backgroundColor: kDrcRed));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(18, 14, 18, MediaQuery.of(context).viewInsets.bottom + 20),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Nouveau produit local', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: kDrcInk)),
          const SizedBox(height: 4),
          const Text('Il sera visible après validation par un modérateur.', style: TextStyle(fontSize: 11, color: kDrcSub)),
          const SizedBox(height: 14),
          TextField(controller: _title, decoration: const InputDecoration(labelText: 'Nom du produit *')),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: TextField(controller: _price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Prix *'))),
            const SizedBox(width: 10),
            Expanded(child: TextField(controller: _stock, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Stock'))),
          ]),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: _sector,
            decoration: const InputDecoration(labelText: 'Secteur'),
            items: kLocalSectors.map((s) => DropdownMenuItem(value: s.id, child: Text(s.label('fr'), style: const TextStyle(fontSize: 13)))).toList(),
            onChanged: (v) => setState(() => _sector = v ?? _sector),
          ),
          const SizedBox(height: 10),
          TextField(controller: _desc, maxLines: 3, decoration: const InputDecoration(labelText: 'Description')),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: _busy ? null : _save,
              style: ElevatedButton.styleFrom(backgroundColor: kDrcBlue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              child: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Soumettre pour validation', style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      ),
    );
  }
}

class _CooperativeFormSheet extends ConsumerStatefulWidget {
  const _CooperativeFormSheet();
  @override
  ConsumerState<_CooperativeFormSheet> createState() => _CooperativeFormSheetState();
}

class _CooperativeFormSheetState extends ConsumerState<_CooperativeFormSheet> {
  final _name = TextEditingController();
  final _city = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _city.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) return;
    setState(() => _busy = true);
    final err = await ref.read(localModerationProvider.notifier).createCooperative(name: _name.text.trim(), city: _city.text.trim());
    if (!mounted) return;
    setState(() => _busy = false);
    if (err == null) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Coopérative créée ✅'), backgroundColor: kDrcBlue));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err), backgroundColor: kDrcRed));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(18, 14, 18, MediaQuery.of(context).viewInsets.bottom + 20),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Créer ma coopérative', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: kDrcInk)),
          const SizedBox(height: 14),
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Nom de la coopérative *')),
          const SizedBox(height: 10),
          TextField(controller: _city, decoration: const InputDecoration(labelText: 'Ville / territoire *')),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: _busy ? null : _save,
              style: ElevatedButton.styleFrom(backgroundColor: kDrcBlue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              child: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Créer', style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      ),
    );
  }
}

class _HighlightFormSheet extends ConsumerStatefulWidget {
  final PortalHighlight? existing;
  const _HighlightFormSheet({this.existing});
  @override
  ConsumerState<_HighlightFormSheet> createState() => _HighlightFormSheetState();
}

class _HighlightFormSheetState extends ConsumerState<_HighlightFormSheet> {
  late final TextEditingController _title = TextEditingController(text: widget.existing?.titleFr ?? '');
  late final TextEditingController _subtitle = TextEditingController(text: widget.existing?.subtitleFr ?? '');
  late String _icon = widget.existing?.icon ?? 'flag';
  bool _busy = false;

  static const _icons = ['flag', 'verified', 'handshake', 'truck', 'eco', 'star', 'store'];

  @override
  void dispose() {
    _title.dispose();
    _subtitle.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) return;
    setState(() => _busy = true);
    final err = await ref.read(localModerationProvider.notifier).saveHighlight(
          id: widget.existing?.id,
          titleFr: _title.text.trim(),
          subtitleFr: _subtitle.text.trim(),
          icon: _icon,
          colorHex: widget.existing?.colorHex ?? '#1E6FD9',
        );
    if (!mounted) return;
    setState(() => _busy = false);
    if (err == null) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(18, 14, 18, MediaQuery.of(context).viewInsets.bottom + 20),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Carte du portail', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: kDrcInk)),
          const SizedBox(height: 14),
          TextField(controller: _title, decoration: const InputDecoration(labelText: 'Titre *')),
          const SizedBox(height: 10),
          TextField(controller: _subtitle, decoration: const InputDecoration(labelText: 'Sous-titre')),
          const SizedBox(height: 12),
          const Text('Icône', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: kDrcSub)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _icons.map((k) {
              final sel = _icon == k;
              return GestureDetector(
                onTap: () => setState(() => _icon = k),
                child: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: sel ? kDrcBlue : kDrcSoft,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: sel ? kDrcBlue : kDrcLine),
                  ),
                  child: Icon(portalHighlightIcon(k), size: 16, color: sel ? Colors.white : kDrcSub),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: _busy ? null : _save,
              style: ElevatedButton.styleFrom(backgroundColor: kDrcBlue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              child: const Text('Enregistrer', style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      ),
    );
  }
}
