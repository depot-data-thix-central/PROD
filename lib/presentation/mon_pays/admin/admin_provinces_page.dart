// lib/presentation/mon_pays/admin/admin_provinces_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/provinces_provider.dart';
import '../models/province.dart';
import 'widgets/admin_confirmation_dialog.dart';

class AdminProvincesPage extends ConsumerStatefulWidget {
  const AdminProvincesPage({super.key});

  @override
  ConsumerState<AdminProvincesPage> createState() => _AdminProvincesPageState();
}

class _AdminProvincesPageState extends ConsumerState<AdminProvincesPage> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedRegion = 'Toutes';

  static const List<String> _regions = ['Toutes', 'Centre', 'Est', 'Ouest', 'Nord', 'Sud'];

  @override
  Widget build(BuildContext context) {
    final adminState = ref.watch(adminProvincesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Administration – Provinces'),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(adminProvincesProvider.notifier).loadProvinces();
            },
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              // NAVIGATION CORRIGÉE ICI (Ajout)
              context.pushNamed('monPaysAdminProvinceForm');
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(70),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Rechercher une province...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _selectedRegion,
                  items: _regions.map((r) {
                    return DropdownMenuItem(value: r, child: Text(r));
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _selectedRegion = value!);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      body: adminState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Erreur : $err')),
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
          if (_selectedRegion != 'Toutes') {
            filtered = filtered.where((p) => p.region == _selectedRegion).toList();
          }
          if (filtered.isEmpty) {
            return const Center(child: Text('Aucune province trouvée.'));
          }
          return ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (_, i) {
              final province = filtered[i];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      image: province.coatOfArmsUrl != null
                          ? DecorationImage(
                              image: NetworkImage(province.coatOfArmsUrl!),
                              fit: BoxFit.contain,
                            )
                          : null,
                      color: Colors.grey.shade200,
                    ),
                    child: province.coatOfArmsUrl == null
                        ? Center(
                            child: Text(
                              province.code.substring(0, 2).toUpperCase(),
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          )
                        : null,
                  ),
                  title: Text(province.name),
                  subtitle: Text('${province.capital} - ${province.region}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () {
                          // NAVIGATION CORRIGÉE ICI (Modification)
                          context.pushNamed(
                            'monPaysAdminProvinceForm',
                            extra: province,
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          _showDeleteConfirmation(province.id);
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showDeleteConfirmation(String id) {
    AdminConfirmationDialog.show(
      context,
      title: 'Suppression de la province',
      message: 'Voulez-vous vraiment supprimer cette province ?',
      confirmText: 'Supprimer',
      cancelText: 'Annuler',
      isDestructive: true,
    ).then((confirmed) {
      if (confirmed == true) {
        ref.read(adminProvincesProvider.notifier).deleteProvince(id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Province supprimée avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      }
    });
  }
}
