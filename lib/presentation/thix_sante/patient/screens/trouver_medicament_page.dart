// lib/presentation/thix_sante/patient/screens/trouver_medicament_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/thix_sante_colors.dart';

const Color tealColor = Color(0xFF14B8A6);

final searchQueryProvider = StateProvider<String>((ref) => '');
final selectedCategoryProvider = StateProvider<String?>((ref) => null);
final selectedPharmacyProvider =
    StateProvider<Map<String, dynamic>?>((ref) => null);
final pharmacySearchProvider = StateProvider<String>((ref) => '');

final nearbyPharmaciesProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final sb = Supabase.instance.client;
  final query = ref.watch(searchQueryProvider).trim();
  final cat = ref.watch(selectedCategoryProvider);

  if (query.isEmpty && cat == null) {
    final res = await sb
        .from('pharmacy')
        .select()
        .order('rating', ascending: false)
        .limit(40);
    return List<Map<String, dynamic>>.from(res);
  }

  final ids = <dynamic>{};

  if (query.isNotEmpty) {
    final byName = await sb.from('pharmacy').select('id').ilike('nom', '%$query%');
    ids.addAll((byName as List).map((e) => e['id']));

    final byMed = await sb
        .from('stocks')
        .select('pharmacy_id')
        .ilike('nom', '%$query%');
    ids.addAll((byMed as List).map((e) => e['pharmacy_id']));
  }

  if (cat != null) {
    final byCat = await sb
        .from('stocks')
        .select('pharmacy_id')
        .eq('categorie', cat);
    final catIds = (byCat as List).map((e) => e['pharmacy_id']).toSet();
    if (query.isEmpty) {
      ids.addAll(catIds);
    } else {
      ids.removeWhere((id) => !catIds.contains(id));
    }
  }

  if (ids.isEmpty) return [];

  final res = await sb
      .from('pharmacy')
      .select()
      .inFilter('id', ids.toList())
      .order('rating', ascending: false);

  return List<Map<String, dynamic>>.from(res);
});

final medicinesByPharmacyProvider = FutureProvider.family<
    List<Map<String, dynamic>>, String>((ref, pharmacyId) async {
  final sb = Supabase.instance.client;
  final q = ref.watch(pharmacySearchProvider).trim();
  final cat = ref.watch(selectedCategoryProvider);

  var req = sb.from('stocks').select().eq('pharmacy_id', pharmacyId);
  if (q.isNotEmpty) req = req.ilike('nom', '%$q%');
  if (cat != null) req = req.eq('categorie', cat);

  final res = await req.order('nom');
  return List<Map<String, dynamic>>.from(res);
});

final cartProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final sb = Supabase.instance.client;
  final user = sb.auth.currentUser;
  if (user == null) return [];
  final res = await sb
      .from('medicine_cart')
      .select('*, stocks(*)')
      .eq('user_id', user.id);
  return List<Map<String, dynamic>>.from(res);
});

class TrouverMedicamentPage extends ConsumerStatefulWidget {
  const TrouverMedicamentPage({super.key});

  @override
  ConsumerState<TrouverMedicamentPage> createState() =>
      _TrouverMedicamentPageState();
}

class _TrouverMedicamentPageState
    extends ConsumerState<TrouverMedicamentPage> {
  final _searchCtrl = TextEditingController();
  final _pharmaSearchCtrl = TextEditingController();
  Timer? _debounce;
  bool _ordering = false;

  final categories = const [
    {'id': 'Toux', 'label': 'Toux', 'icon': Icons.sick_rounded},
    {'id': 'Douleur', 'label': 'Douleur', 'icon': Icons.healing_rounded},
    {'id': 'Peau', 'label': 'Peau', 'icon': Icons.face_rounded},
    {'id': 'Tête', 'label': 'Maux de tête', 'icon': Icons.psychology_rounded},
    {'id': 'Fièvre', 'label': 'Fièvre', 'icon': Icons.thermostat_rounded},
    {'id': 'Fatigue', 'label': 'Fatigue', 'icon': Icons.battery_0_bar_rounded},
    {'id': 'Digestion', 'label': 'Digestion', 'icon': Icons.restaurant_rounded},
    {'id': 'Diabète', 'label': 'Diabète', 'icon': Icons.bloodtype_rounded},
    {'id': 'Yeux', 'label': 'Yeux', 'icon': Icons.remove_red_eye_rounded},
  ];

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _pharmaSearchCtrl.dispose();
    super.dispose();
  }

  void _onSearch(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      ref.read(searchQueryProvider.notifier).state = v;
    });
  }

  @override
  Widget build(BuildContext context) {
    final selected = ref.watch(selectedPharmacyProvider);
    final cart = ref.watch(cartProvider);

    final items = cart.valueOrNull ?? [];
    final pharmacyId = selected?['id'];
    final scoped = pharmacyId == null
        ? items
        : items
            .where((i) =>
                i['pharmacy_id'] == pharmacyId ||
                i['stocks']?['pharmacy_id'] == pharmacyId)
            .toList();

    final total = scoped.fold<double>(0, (s, i) {
      final price = (i['stocks']?['prix'] as num?)?.toDouble() ?? 0;
      final qty = (i['quantity'] as num?)?.toInt() ?? 1;
      return s + price * qty;
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      body: selected == null
          ? _buildStoreList()
          : _buildPharmacyDetail(selected),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: (scoped.isNotEmpty && selected != null)
          ? _buildCartBar(scoped.length, total, selected)
          : null,
    );
  }

  Widget _buildStoreList() {
    final nearby = ref.watch(nearbyPharmaciesProvider);
    final selectedCat = ref.watch(selectedCategoryProvider);

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          backgroundColor: const Color(0xFFE9D5FF),
          expandedHeight: 200,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.pop(context),
          ),
          flexibleSpace: FlexibleSpaceBar(
            background: Padding(
              padding: const EdgeInsets.fromLTRB(16, 80, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Trouver un médicament',
                      style: TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _searchCtrl,
                    onChanged: _onSearch,
                    decoration: InputDecoration(
                      hintText: 'Médicament ou pharmacie…',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.15,
            ),
            delegate: SliverChildBuilderDelegate((context, i) {
              final c = categories[i];
              final selected = selectedCat == c['id'];
              return GestureDetector(
                onTap: () => ref.read(selectedCategoryProvider.notifier).state =
                    selected ? null : c['id'] as String,
                child: Container(
                  decoration: BoxDecoration(
                    color: selected ? ThixSanteColors.primary : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: selected
                            ? ThixSanteColors.primary
                            : const Color(0xFFE5E7EB)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(c['icon'] as IconData,
                          color: selected ? Colors.white : Colors.black87),
                      const SizedBox(height: 6),
                      Text(c['label'] as String,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: selected ? Colors.white : Colors.black,
                          )),
                    ],
                  ),
                ),
              );
            }, childCount: categories.length),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                const Text('Pharmacies',
                    style:
                        TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                const Spacer(),
                if (selectedCat != null)
                  TextButton(
                    onPressed: () => ref
                        .read(selectedCategoryProvider.notifier)
                        .state = null,
                    child: const Text('Effacer filtre'),
                  ),
              ],
            ),
          ),
        ),
        nearby.when(
          loading: () => const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
          error: (e, _) => SliverToBoxAdapter(child: Text('Erreur : $e')),
          data: (stores) {
            if (stores.isEmpty) {
              return const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: Text('Aucune pharmacie pour cette recherche',
                        style: TextStyle(color: Colors.grey)),
                  ),
                ),
              );
            }
            return SliverList.builder(
              itemCount: stores.length,
              itemBuilder: (c, i) => _storeCard(stores[i], onTap: () {
                ref.read(selectedPharmacyProvider.notifier).state = stores[i];
                ref.read(pharmacySearchProvider.notifier).state = '';
              }),
            );
          },
        ),
      ],
    );
  }

  Widget _buildPharmacyDetail(Map<String, dynamic> pharmacy) {
    final medsAsync =
        ref.watch(medicinesByPharmacyProvider(pharmacy['id'].toString()));

    return Column(
      children: [
        AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () =>
                ref.read(selectedPharmacyProvider.notifier).state = null,
          ),
          title: Text(pharmacy['nom']?.toString() ?? 'Pharmacie',
              style: const TextStyle(
                  color: Colors.black, fontWeight: FontWeight.w800)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(
            controller: _pharmaSearchCtrl,
            onChanged: (v) =>
                ref.read(pharmacySearchProvider.notifier).state = v,
            decoration: InputDecoration(
              hintText: 'Filtrer les stocks…',
              prefixIcon: const Icon(Icons.search, size: 20),
              filled: true,
              fillColor: Colors.white,
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        if (pharmacy['adresse'] != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(pharmacy['adresse'].toString(),
                  style: const TextStyle(color: Colors.grey, fontSize: 13)),
            ),
          ),
        const SizedBox(height: 8),
        Expanded(
          child: medsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Erreur : $e')),
            data: (meds) {
              if (meds.isEmpty) {
                return const Center(child: Text('Aucun stock pour ce filtre'));
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                itemCount: meds.length,
                itemBuilder: (_, i) => _medicineTile(meds[i], pharmacy),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _storeCard(Map<String, dynamic> store, {VoidCallback? onTap}) {
    final rating = store['rating'];
    final delay = store['delivery_time_min'];
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: ListTile(
        onTap: onTap,
        leading: const CircleAvatar(child: Icon(Icons.local_pharmacy_rounded)),
        title: Text(store['nom']?.toString() ?? '',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        subtitle: Text(store['adresse']?.toString() ?? '',
            style: const TextStyle(fontSize: 11, color: Colors.grey)),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (rating != null)
              Text('★ ${rating.toString()}',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700)),
            if (delay != null)
              Text('$delay min',
                  style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _medicineTile(
      Map<String, dynamic> med, Map<String, dynamic> pharmacy) {
    final sb = Supabase.instance.client;
    final cart = ref.watch(cartProvider).valueOrNull ?? [];
    final inCart = cart.cast<Map>().firstWhere(
          (i) => i['medicine_id'] == med['id'],
          orElse: () => {},
        );
    final qty = inCart.isNotEmpty ? (inCart['quantity'] as num?)?.toInt() ?? 0 : 0;
    final stock = (med['quantite'] as num?)?.toInt() ?? 0;
    final currency = med['currency']?.toString() ?? 'CDF';
    final price = (med['prix'] as num?)?.toDouble() ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.medication, size: 36, color: Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(med['nom']?.toString() ?? 'Médicament',
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                Text('${price.toStringAsFixed(0)} $currency',
                    style: const TextStyle(color: Colors.grey, fontSize: 13)),
                Text(
                  stock > 0 ? 'Stock : $stock' : 'Rupture',
                  style: TextStyle(
                    fontSize: 11,
                    color: stock > 0 ? Colors.green : Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (stock <= 0)
            const Text('Indispo', style: TextStyle(color: Colors.red))
          else if (qty == 0)
            OutlinedButton(
              onPressed: () => _setQty(sb, med, pharmacy, 1),
              style: OutlinedButton.styleFrom(foregroundColor: tealColor),
              child: const Text('Ajouter'),
            )
          else
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: () => _setQty(sb, med, pharmacy, qty - 1),
                ),
                Text('$qty',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: qty >= stock
                      ? null
                      : () => _setQty(sb, med, pharmacy, qty + 1),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _setQty(
    SupabaseClient sb,
    Map<String, dynamic> med,
    Map<String, dynamic> pharmacy,
    int qty,
  ) async {
    final user = sb.auth.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Connectez-vous pour commander')),
        );
      }
      return;
    }
    try {
      if (qty <= 0) {
        await sb
            .from('medicine_cart')
            .delete()
            .eq('user_id', user.id)
            .eq('medicine_id', med['id']);
      } else {
        await sb.from('medicine_cart').upsert({
          'user_id': user.id,
          'pharmacy_id': pharmacy['id'],
          'medicine_id': med['id'],
          'quantity': qty,
          'updated_at': DateTime.now().toIso8601String(),
        }, onConflict: 'user_id,medicine_id');
      }
      ref.invalidate(cartProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur panier : $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildCartBar(
      int count, double total, Map<String, dynamic> pharmacy) {
    return GestureDetector(
      onTap: () => _showCheckout(pharmacy, total),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: tealColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Text('$count article(s) · ${total.toStringAsFixed(0)}',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w800)),
            const Spacer(),
            const Text('Commander',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }

  void _showCheckout(Map<String, dynamic> pharmacy, double total) {
    final addressCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Confirmer la commande',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
            const SizedBox(height: 12),
            TextField(
              controller: addressCtrl,
              decoration: const InputDecoration(
                labelText: 'Adresse de livraison *',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: tealColor),
                onPressed: _ordering
                    ? null
                    : () => _placeOrder(
                          pharmacy,
                          total,
                          addressCtrl.text.trim(),
                        ),
                child: Text(_ordering
                    ? 'Envoi…'
                    : 'Valider · ${total.toStringAsFixed(0)}'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _placeOrder(
    Map<String, dynamic> pharmacy,
    double total,
    String address,
  ) async {
    if (address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Adresse obligatoire')),
      );
      return;
    }
    final sb = Supabase.instance.client;
    final user = sb.auth.currentUser;
    if (user == null) return;

    setState(() => _ordering = true);
    try {
      final items = (ref.read(cartProvider).valueOrNull ?? [])
          .where((i) =>
              i['pharmacy_id'] == pharmacy['id'] ||
              i['stocks']?['pharmacy_id'] == pharmacy['id'])
          .toList();

      final order = await sb
          .from('medicine_orders')
          .insert({
            'user_id': user.id,
            'pharmacy_id': pharmacy['id'],
            'status': 'pending',
            'total': total,
            'delivery_address': address,
          })
          .select()
          .single();

      for (final i in items) {
        final stock = i['stocks'] as Map?;
        final qty = (i['quantity'] as num?)?.toInt() ?? 1;
        final price = (stock?['prix'] as num?)?.toDouble() ?? 0;
        await sb.from('medicine_order_items').insert({
          'order_id': order['id'],
          'medicine_id': i['medicine_id'],
          'nom': stock?['nom'] ?? 'Médicament',
          'unit_price': price,
          'quantity': qty,
          'line_total': price * qty,
        });
      }

      await sb
          .from('medicine_cart')
          .delete()
          .eq('user_id', user.id)
          .eq('pharmacy_id', pharmacy['id']);

      ref.invalidate(cartProvider);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Commande enregistrée'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur commande : $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _ordering = false);
    }
  }
}
