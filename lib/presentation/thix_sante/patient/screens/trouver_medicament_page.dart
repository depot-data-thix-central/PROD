// lib/presentation/thix_sante/patient/screens/trouver_medicament_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/thix_sante_colors.dart';

// ================= COULEURS DU DESIGN =================
const Color tealColor = Color(0xFF14B8A6); // Couleur turquoise de l'image

// ================= PROVIDERS =================
final searchQueryProvider = StateProvider<String>((ref) => '');
final selectedCategoryProvider = StateProvider<String?>((ref) => null);
final selectedPharmacyProvider = StateProvider<Map<String, dynamic>?>((ref) => null);

final nearbyPharmaciesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = Supabase.instance.client;
  final query = ref.watch(searchQueryProvider);
  final cat = ref.watch(selectedCategoryProvider);

  if (query.isNotEmpty) {
    // 1. Chercher les pharmacies dont le nom correspond (table: pharmacy)
    final matchingPharmacies = await supabase
        .from('pharmacy')
        .select()
        .ilike('nom', '%$query%');
    
    final pharmacyIdsFromNames = matchingPharmacies.map((e) => e['id']).toSet();

    // 2. Chercher les médicaments (table: stocks) dont le nom correspond
    final matchingMeds = await supabase
        .from('stocks')
        .select('pharmacy_id')
        .ilike('nom', '%$query%');
        
    final pharmacyIdsFromMeds = matchingMeds.map((e) => e['pharmacy_id']).toSet();

    // Combiner tous les IDs de pharmacies trouvées
    final allIds = {...pharmacyIdsFromNames, ...pharmacyIdsFromMeds};

    if (allIds.isEmpty) {
      return [];
    }

    final res = await supabase
        .from('pharmacy')
        .select()
        .inFilter('id', allIds.toList())
        .order('rating', ascending: false);

    var list = List<Map<String, dynamic>>.from(res);

    // Filtrer par catégorie si sélectionnée
    if (cat != null) {
      final medsCat = await supabase
          .from('stocks')
          .select('pharmacy_id')
          .eq('categorie', cat);
          
      final idsCat = medsCat.map((e) => e['pharmacy_id']).toSet();
      
      list = list.where((p) => idsCat.contains(p['id'])).toList();
    }
    return list;
    
  } else {
    // Si la recherche est vide, on liste les pharmacies normalement
    var q = supabase.from('pharmacy').select();
    final res = await q.order('rating', ascending: false).limit(20);
    
    var list = List<Map<String, dynamic>>.from(res);

    // Filtre catégorie si sélectionnée
    if (cat != null) {
      final meds = await supabase
          .from('stocks')
          .select('pharmacy_id')
          .eq('categorie', cat);
          
      final ids = meds.map((e) => e['pharmacy_id']).toSet();
      
      list = list.where((p) => ids.contains(p['id'])).toList();
    }
    return list;
  }
});

final medicinesByPharmacyProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, pharmacyId) async {
  final supabase = Supabase.instance.client;
  
  final res = await supabase
      .from('stocks')
      .select()
      .eq('pharmacy_id', pharmacyId)
      .order('nom');
      
  return List<Map<String, dynamic>>.from(res);
});

final cartProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final supabase = Supabase.instance.client;
  final user = supabase.auth.currentUser;
  
  if (user == null) {
    return [];
  }
  
  // Jointure avec la table stocks
  final res = await supabase
      .from('medicine_cart')
      .select('*, stocks(*)')
      .eq('user_id', user.id);
      
  return List<Map<String, dynamic>>.from(res);
});

// ================= PAGE PRINCIPALE =================
class TrouverMedicamentPage extends ConsumerStatefulWidget {
  const TrouverMedicamentPage({super.key});

  @override 
  ConsumerState<TrouverMedicamentPage> createState() => _TrouverMedicamentPageState();
}

class _TrouverMedicamentPageState extends ConsumerState<TrouverMedicamentPage> {
  final categories = [
    {'id': 'Toux', 'label': 'Toux', 'icon': Icons.sick_rounded, 'color': const Color(0xFFFFE4E6)},
    {'id': 'Douleur', 'label': 'Douleur', 'icon': Icons.healing_rounded, 'color': const Color(0xFFDCFCE7)},
    {'id': 'Peau', 'label': 'Peau', 'icon': Icons.face_rounded, 'color': const Color(0xFFFFF7CC)},
    {'id': 'Tête', 'label': 'Maux de tête', 'icon': Icons.psychology_rounded, 'color': const Color(0xFFDBEAFE)},
    {'id': 'Fièvre', 'label': 'Fièvre', 'icon': Icons.thermostat_rounded, 'color': const Color(0xFFE0E7FF)},
    {'id': 'Fatigue', 'label': 'Fatigue', 'icon': Icons.battery_0_bar_rounded, 'color': const Color(0xFFFEF3C7)},
    {'id': 'Digestion', 'label': 'Digestion', 'icon': Icons.restaurant_rounded, 'color': const Color(0xFFFFE4D6)},
    {'id': 'Diabète', 'label': 'Diabète', 'icon': Icons.bloodtype_rounded, 'color': const Color(0xFFD1FAE5)},
    {'id': 'Yeux', 'label': 'Yeux', 'icon': Icons.remove_red_eye_rounded, 'color': const Color(0xFFE0F2FE)},
  ];

  @override
  Widget build(BuildContext context) {
    final selectedPharmacy = ref.watch(selectedPharmacyProvider);
    final cart = ref.watch(cartProvider);
    
    final cartTotal = cart.when(
      data: (list) {
        return list.fold<double>(0.0, (sum, item) {
          final price = item['stocks']?['prix'] ?? 0;
          final quantity = item['quantity'] ?? 1;
          return sum + (price * quantity);
        });
      }, 
      loading: () => 0.0, 
      error: (_, __) => 0.0,
    );

    final cartCount = cart.when(
      data: (list) => list.length, 
      loading: () => 0, 
      error: (_, __) => 0,
    );

    return Scaffold(
      backgroundColor: Colors.white,
      body: selectedPharmacy == null 
          ? _buildStoreList() 
          : _buildPharmacyDetail(selectedPharmacy),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: (cartCount > 0 && selectedPharmacy != null) 
          ? _buildCartBar(cartCount, cartTotal) 
          : null,
    );
  }

  Widget _buildStoreList() {
    final searchCtrl = TextEditingController(text: ref.read(searchQueryProvider));
    final nearby = ref.watch(nearbyPharmaciesProvider);
    final selectedCat = ref.watch(selectedCategoryProvider);

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true, 
          backgroundColor: const Color(0xFFE9D5FF),
          expandedHeight: 220,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.black), 
            onPressed: () => Navigator.pop(context)
          ),
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(
              children: [
                Positioned(
                  right: 20, 
                  top: 40, 
                  child: Icon(Icons.medication_rounded, size: 100, color: Colors.white.withOpacity(0.5))
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 80, 16, 16), 
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, 
                    children: [
                      const Text(
                        'TROUVER UN MÉDICAMENT', 
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)
                      ),
                      const SizedBox(height: 16),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white, 
                          borderRadius: BorderRadius.circular(12), 
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)
                          ]
                        ),
                        child: TextField(
                          controller: searchCtrl,
                          textAlign: TextAlign.start,
                          onChanged: (value) {
                            ref.read(searchQueryProvider.notifier).state = value;
                          },
                          decoration: const InputDecoration(
                            hintText: 'Rechercher un médicament...', 
                            prefixIcon: Icon(Icons.search), 
                            border: InputBorder.none, 
                            contentPadding: EdgeInsets.all(14)
                          ),
                        ),
                      ),
                    ]
                  )
                ),
              ]
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(16), 
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, 
              mainAxisSpacing: 12, 
              crossAxisSpacing: 12, 
              childAspectRatio: 1.1
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final category = categories[index];
                final isSelected = selectedCat == category['id'];
                
                return GestureDetector(
                  onTap: () {
                    ref.read(selectedCategoryProvider.notifier).state = 
                        isSelected ? null : category['id'] as String;
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected ? ThixSanteColors.primary : Colors.white, 
                      borderRadius: BorderRadius.circular(14), 
                      border: Border.all(color: isSelected ? ThixSanteColors.primary : const Color(0xFFE5E7EB))
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center, 
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8), 
                          decoration: BoxDecoration(
                            color: (category['color'] as Color), 
                            shape: BoxShape.circle
                          ), 
                          child: Icon(category['icon'] as IconData, size: 22, color: Colors.black87)
                        ),
                        const SizedBox(height: 6),
                        Text(
                          category['label'] as String, 
                          style: TextStyle(
                            fontSize: 11, 
                            fontWeight: FontWeight.w700, 
                            color: isSelected ? Colors.white : Colors.black
                          )
                        ),
                      ]
                    ),
                  ),
                );
              }, 
              childCount: categories.length
            ),
          )
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8), 
            child: Row(
              children: [
                const Text(
                  'Pharmacies à proximité', 
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)
                ),
                const Spacer(),
                if (selectedCat != null) 
                  TextButton(
                    onPressed: () {
                      ref.read(selectedCategoryProvider.notifier).state = null;
                    }, 
                    child: const Text('Effacer', style: TextStyle(color: Colors.red))
                  ),
              ]
            )
          )
        ),
        nearby.when(
          loading: () => const SliverToBoxAdapter(
            child: Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
          ),
          error: (error, _) => SliverToBoxAdapter(
            child: Center(child: Text('Erreur: $error'))
          ),
          data: (stores) => SliverList.builder(
            itemCount: stores.length,
            itemBuilder: (context, index) {
              final store = stores[index];
              return _storeCard(
                store, 
                onTap: () {
                  ref.read(selectedPharmacyProvider.notifier).state = store;
                }
              );
            },
          ),
        ),
      ],
    );
  }

  // ================= DESIGN DE LA PAGE PHARMACIE (Basé sur l'image) =================
  Widget _buildPharmacyDetail(Map<String, dynamic> pharmacy) {
    final medicinesAsync = ref.watch(medicinesByPharmacyProvider(pharmacy['id']));
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white, 
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black, size: 20), 
          onPressed: () {
            ref.read(selectedPharmacyProvider.notifier).state = null;
          }
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.black), 
            onPressed: () {}
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête : Nom et Adresse
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pharmacy['nom'] ?? 'Pharmacie Inconnue', 
                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 22)
                ),
                const SizedBox(height: 6),
                Text(
                  '${pharmacy['adresse'] ?? 'Adresse non spécifiée'} | ${pharmacy['distance'] ?? '1.5 km'}', 
                  style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500)
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Ligne des statistiques (Notes et Livraison)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _infoStatBadge(
                  Icons.star, 
                  '${pharmacy['total_ratings'] ?? '60+' } avis', 
                  '${pharmacy['rating'] ?? '4.0'}'
                ),
                Container(width: 1, height: 40, color: Colors.grey.shade200),
                _infoStatBadge(
                  Icons.pedal_bike_rounded, 
                  'Livraison en', 
                  '${pharmacy['delivery_time_min'] ?? 20} mins'
                ),
              ]
            ),
          ),
          
          const SizedBox(height: 20),
          Divider(color: Colors.grey.shade100, thickness: 8),
          const SizedBox(height: 16),
          
          // Titre de la catégorie
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Tous les médicaments', 
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)
                ),
                Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey.shade600),
              ]
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Liste des médicaments
          Expanded(
            child: medicinesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: tealColor)),
              error: (error, _) => Center(child: Text('Erreur: $error')),
              data: (meds) {
                if (meds.isEmpty) {
                  return const Center(child: Text('Aucun médicament en stock.'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  itemCount: meds.length, 
                  itemBuilder: (context, index) {
                    final medicine = meds[index];
                    return _medicineTile(medicine);
                  }
                );
              },
            )
          ),
        ]
      ),
    );
  }

  Widget _infoStatBadge(IconData icon, String subtitle, String title) {
    return Column(
      children: [
        Text(
          subtitle, 
          style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500)
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Icon(icon, size: 20, color: tealColor),
            const SizedBox(width: 6),
            Text(
              title, 
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)
            ),
          ],
        ),
      ],
    );
  }

  Widget _storeCard(Map<String, dynamic> store, {VoidCallback? onTap}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(14), 
        border: Border.all(color: const Color(0xFFE5E7EB))
      ),
      child: ListTile(
        onTap: onTap,
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(10), 
          child: Image.network(
            store['image_url'] ?? 'https://via.placeholder.com/60', 
            width: 60, 
            height: 60, 
            fit: BoxFit.cover, 
            errorBuilder: (_, __, ___) => Container(
              width: 60, 
              height: 60, 
              color: const Color(0xFFF3F4F6), 
              child: const Icon(Icons.local_pharmacy_rounded)
            )
          )
        ),
        title: Text(
          store['nom'] ?? '', 
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start, 
          children: [
            Text(
              store['adresse'] ?? 'Adresse inconnue', 
              style: const TextStyle(fontSize: 11, color: Colors.grey)
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.delivery_dining, size: 12, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  'Livraison en ${store['delivery_time_min'] ?? 20} min', 
                  style: const TextStyle(fontSize: 10)
                ),
                const SizedBox(width: 12),
                Text(
                  '${store['distance'] ?? '1.5 km'}', 
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)
                ),
              ]
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), 
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E), 
                    borderRadius: BorderRadius.circular(6)
                  ), 
                  child: Row(
                    children: [
                      const Icon(Icons.star, size: 10, color: Colors.white), 
                      const SizedBox(width: 2), 
                      Text(
                        '${store['rating'] ?? '4.0'}', 
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)
                      )
                    ]
                  )
                ),
                const SizedBox(width: 6),
                Text(
                  '${store['total_ratings'] ?? '256'} avis', 
                  style: const TextStyle(fontSize: 10, color: Colors.grey)
                ),
              ]
            ),
          ]
        ),
      ),
    );
  }

  // ================= TILE DU MÉDICAMENT =================
  Widget _medicineTile(Map<String, dynamic> medicine) {
    final supabase = Supabase.instance.client;
    final cartList = ref.watch(cartProvider).value ?? [];
    
    final inCart = cartList.firstWhere(
      (item) => item['medicine_id'] == medicine['id'], 
      orElse: () => {}
    );
    
    final int qty = inCart.isNotEmpty ? (inCart['quantity'] as int) : 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image à gauche avec icône Rx
          Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200)
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12), 
                  child: Image.network(
                    medicine['image_url'] ?? '', 
                    width: 70, 
                    height: 70, 
                    fit: BoxFit.cover, 
                    errorBuilder: (_, __, ___) => const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: Icon(Icons.medication, size: 40, color: Colors.grey),
                    )
                  )
                ),
              ),
              if (medicine['prescription_requise'] == true)
                const Positioned(
                  top: -2,
                  right: -2,
                  child: Text('Rx', style: TextStyle(color: tealColor, fontWeight: FontWeight.w900, fontSize: 14)),
                )
            ],
          ),
          
          const SizedBox(width: 16),
          
          // Informations à droite
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, 
              children: [
                Text(
                  medicine['nom'] ?? 'Médicament', 
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Colors.black87)
                ),
                const SizedBox(height: 4),
                Text(
                  '${medicine['prix'] ?? '0.00'} €', 
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Colors.grey)
                ),
                const SizedBox(height: 12),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Sélecteur de boîte
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), 
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300), 
                        borderRadius: BorderRadius.circular(20),
                        color: Colors.grey.shade50
                      ), 
                      child: Row(
                        children: [
                          Text(
                            medicine['pack_size'] ?? 'Boîte de 10', 
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.w600)
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.keyboard_arrow_down, size: 14, color: Colors.grey.shade700)
                        ],
                      )
                    ),
                    
                    // Boutons Ajouter ou Quantité
                    qty == 0 
                      ? OutlinedButton(
                          onPressed: () async {
                            final user = supabase.auth.currentUser;
                            if (user == null) return;
                            
                            await supabase.from('medicine_cart').upsert({
                              'user_id': user.id, 
                              'medicine_id': medicine['id'], 
                              'quantity': 1
                            });
                            ref.invalidate(cartProvider);
                          }, 
                          style: OutlinedButton.styleFrom(
                            foregroundColor: tealColor,
                            side: const BorderSide(color: tealColor, width: 1.5), 
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0)
                          ), 
                          child: const Text('Ajouter', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold))
                        )
                      : Container(
                          decoration: BoxDecoration(
                            color: tealColor, 
                            borderRadius: BorderRadius.circular(20)
                          ), 
                          child: Row(
                            mainAxisSize: MainAxisSize.min, 
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove, size: 18, color: Colors.white), 
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                constraints: const BoxConstraints(),
                                onPressed: () async {
                                  final user = supabase.auth.currentUser; 
                                  if (user == null) return;
                                  
                                  if (qty <= 1) {
                                    await supabase.from('medicine_cart')
                                      .delete()
                                      .eq('user_id', user.id)
                                      .eq('medicine_id', medicine['id']);
                                  } else {
                                    await supabase.from('medicine_cart')
                                      .update({'quantity': qty - 1})
                                      .eq('user_id', user.id)
                                      .eq('medicine_id', medicine['id']);
                                  }
                                  ref.invalidate(cartProvider);
                                }
                              ),
                              Text(
                                '$qty', 
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)
                              ),
                              IconButton(
                                icon: const Icon(Icons.add, size: 18, color: Colors.white), 
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                constraints: const BoxConstraints(),
                                onPressed: () async {
                                  final user = supabase.auth.currentUser; 
                                  if (user == null) return;
                                  
                                  await supabase.from('medicine_cart')
                                    .update({'quantity': qty + 1})
                                    .eq('user_id', user.id)
                                    .eq('medicine_id', medicine['id']);
                                    
                                  ref.invalidate(cartProvider);
                                }
                              ),
                            ]
                          )
                        ),
                  ],
                ),
              ]
            ),
          ),
        ]
      ),
    );
  }

  // ================= BARRE PANIER FLOTTANTE =================
  Widget _buildCartBar(int count, double total) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20, left: 16, right: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: tealColor, 
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: tealColor.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 4))
          ]
        ),
        child: Row(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count Article(s) • ${total.toStringAsFixed(2)} €', 
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)
                ),
                const SizedBox(height: 2),
                Text(
                  'Frais supplémentaires applicables', 
                  style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 10)
                ),
              ],
            ),
            const Spacer(),
            GestureDetector(
              onTap: () => _showCheckout(),
              child: const Row(
                children: [
                  Icon(Icons.shopping_basket_rounded, color: Colors.white, size: 20), 
                  SizedBox(width: 8), 
                  Text(
                    'Voir le panier', 
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)
                  )
                ]
              ),
            ),
          ]
        ),
      ),
    );
  }

  void _showCheckout() {
    showModalBottomSheet(
      context: context, 
      isScrollControlled: true, 
      backgroundColor: Colors.white, 
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), 
      builder: (context) {
        final cart = ref.watch(cartProvider);
        
        return Padding(
          padding: const EdgeInsets.all(20), 
          child: Column(
            mainAxisSize: MainAxisSize.min, 
            children: [
              const Text(
                'Confirmer la commande', 
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)
              ),
              const SizedBox(height: 20),
              
              cart.when(
                data: (items) {
                  return Column(
                    children: items.map((item) {
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(item['stocks']['nom'], style: const TextStyle(fontWeight: FontWeight.bold)), 
                        subtitle: Text('Quantité: ${item['quantity']}'), 
                        trailing: Text(
                          '${(item['stocks']['prix'] * item['quantity']).toStringAsFixed(2)} €',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
                        )
                      );
                    }).toList()
                  );
                }, 
                loading: () => const CircularProgressIndicator(color: tealColor), 
                error: (error, __) => Text('Erreur: $error')
              ),
              
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity, 
                height: 54, 
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tealColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                  ),
                  onPressed: () async {
                    Navigator.pop(context);
                    
                    showDialog(
                      context: context, 
                      builder: (_) => Dialog(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        child: Container(
                          height: 400, 
                          padding: const EdgeInsets.all(20), 
                          child: Column(
                            children: [
                              const Text(
                                'Livraison en cours !', 
                                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Votre livreur arrive dans 20 mins', 
                                style: TextStyle(color: Colors.grey)
                              ),
                              const SizedBox(height: 20),
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE5E7EB), 
                                    borderRadius: BorderRadius.circular(16)
                                  ), 
                                  child: const Center(child: Icon(Icons.map_rounded, size: 60, color: Colors.grey))
                                )
                              ),
                              const SizedBox(height: 20),
                              const ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(backgroundColor: tealColor, child: Icon(Icons.person, color: Colors.white)), 
                                title: Text('Livreur Pharmacie', style: TextStyle(fontWeight: FontWeight.bold)), 
                                subtitle: Text('En route...')
                              ),
                            ]
                          )
                        )
                      )
                    ); 
                  },
                  child: const Text(
                    'VALIDER - LIVRAISON 20 MIN', 
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)
                  ),
                )
              ),
              const SizedBox(height: 20),
            ]
          )
        );
      }
    );
  }
}
