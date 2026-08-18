// ============================================================
// FICHIER : pages/provinces/provinces_page.dart
// ============================================================
// lib/presentation/mon_pays/pages/provinces/provinces_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/province.dart';
import '../../providers/provinces_provider.dart';
import '../../cards/province_card.dart';

class ProvincesPage extends ConsumerStatefulWidget {
  const ProvincesPage({super.key});

  @override
  ConsumerState<ProvincesPage> createState() => _ProvincesPageState();
}

class _ProvincesPageState extends ConsumerState<ProvincesPage> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedRegion = 'Toutes';

  static const List<String> _regions = ['Toutes', 'Centre', 'Est', 'Ouest', 'Nord', 'Sud'];

  // Charte graphique "Mon Pays"
  static const Color navyDeep = Color(0xFF0A1F44);
  static const Color redThix = Color(0xFFD32F2F);
  static const Color lightBg = Color(0xFFF6F7FB);
  static const Color mutedText = Color(0xFF6B7690);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final region = _selectedRegion == 'Toutes' ? null : _selectedRegion;
    final provincesAsync = ref.watch(provincesProvider(region));

    return Scaffold(
      backgroundColor: lightBg,
      appBar: AppBar(
        title: const Text('Provinces de la RDC', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: redThix,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      body: Column(
        children: [
          // En-tête avec Recherche et Filtres
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            decoration: BoxDecoration(
              color: redThix,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Column(
              children: [
                // Barre de recherche modernisée
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      )
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Rechercher une province, capitale...',
                      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                      prefixIcon: const Icon(Icons.search, color: navyDeep),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: Colors.grey),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Filtres par région (Chips horizontaux)
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _regions.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final r = _regions[index];
                      final isSelected = _selectedRegion == r;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedRegion = r),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.white : Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected ? Colors.white : Colors.transparent,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              r,
                              style: TextStyle(
                                color: isSelected ? redThix : Colors.white,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Liste des provinces
          Expanded(
            child: provincesAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: navyDeep),
              ),
              error: (err, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 48),
                    const SizedBox(height: 16),
                    Text('Erreur de chargement', style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () => ref.invalidate(provincesProvider(region)),
                      style: ElevatedButton.styleFrom(backgroundColor: navyDeep),
                      child: const Text('Réessayer', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ),
              data: (provinces) {
                final query = _searchController.text.trim().toLowerCase();
                List<Province> filtered = provinces;
                
                if (query.isNotEmpty) {
                  filtered = provinces.where((p) =>
                      p.name.toLowerCase().contains(query) ||
                      p.capital.toLowerCase().contains(query) ||
                      p.code.toLowerCase().contains(query)
                  ).toList();
                }

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.map_outlined, size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        const Text(
                          'Aucune province trouvée.',
                          style: TextStyle(fontSize: 16, color: mutedText, fontWeight: FontWeight.w600),
                        ),
                        if (query.isNotEmpty)
                          Text(
                            'Essayez un autre mot-clé',
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                          ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  physics: const BouncingScrollPhysics(),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final province = filtered[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ProvinceCard(
                        province: province,
                        onTap: () => context.push('/mon-pays/provinces/${province.id}'),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
