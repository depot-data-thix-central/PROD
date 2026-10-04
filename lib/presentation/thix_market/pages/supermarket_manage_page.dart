// lib/presentation/thix_market/pages/supermarket_manage_page.dart
// ============================================================================
// GESTION DES RAYONS — côté vendeur
// Sélection d'une allée → ajout / retrait de produits
// ============================================================================

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/presentation/thix_market/models/supermarket_models.dart';
import 'package:thix_id/presentation/thix_market/providers/supermarket_providers.dart';
import 'package:thix_id/services/supermarket_service.dart';

class SupermarketManagePage extends ConsumerStatefulWidget {
  final String supermarketId;
  const SupermarketManagePage({super.key, required this.supermarketId});

  @override
  ConsumerState<SupermarketManagePage> createState() =>
      _SupermarketManagePageState();
}

class _SupermarketManagePageState extends ConsumerState<SupermarketManagePage> {
  String? _selectedDeptId;
  final _service = SupermarketService();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final deptsAsync = ref.watch(departmentsProvider(widget.supermarketId));
    final productsAsync =
        ref.watch(supermarketAllProductsProvider(widget.supermarketId));

    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      appBar: AppBar(
        backgroundColor: ThixPolicy.primaryDeep,
        foregroundColor: Colors.white,
        title: Text(_tr(l10n, 'sm_manage_title', 'Gérer les rayons')),
      ),
      body: deptsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (depts) {
          if (depts.isEmpty) {
            return const Center(child: Text('Aucun rayon'));
          }
          // Sélection par défaut = 1er rayon
          if (_selectedDeptId == null ||
              !depts.any((d) => d.id == _selectedDeptId)) {
            _selectedDeptId = depts.first.id;
          }
          final selectedIdx =
              depts.indexWhere((d) => d.id == _selectedDeptId);
          final selected = depts[selectedIdx];
          final aisleNumber = selectedIdx + 1;

          final all = productsAsync.valueOrNull ?? [];
          final inDept = all
              .where((p) => p['department_id']?.toString() == selected.id)
              .toList();

          return Column(
            children: [
              // ── Chips des rayons ──
              SizedBox(
                height: 52,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: depts.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final d = depts[i];
                    final sel = d.id == _selectedDeptId;
                    final count = all
                        .where((p) => p['department_id']?.toString() == d.id)
                        .length;
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedDeptId = d.id);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: sel ? d.color : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: sel ? d.color : ThixPolicy.border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(d.icon,
                                size: 15,
                                color: sel ? Colors.white : d.color),
                            const SizedBox(width: 6),
                            Text(
                              '${i + 1}. ${d.name}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: sel ? Colors.white : ThixPolicy.textMain,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: sel
                                    ? Colors.white.withOpacity(0.25)
                                    : d.color.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text('$count',
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      color: sel ? Colors.white : d.color)),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const Divider(height: 1),

              // ── Produits du rayon sélectionné ──
              Expanded(
                child: productsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('$e')),
                  data: (_) {
                    if (inDept.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.inventory_2_outlined,
                                size: 48, color: selected.color.withOpacity(0.5)),
                            const SizedBox(height: 12),
                            Text(
                              _tr(l10n, 'sm_dept_empty_manage',
                                  'Rayon vide — ajoutez des produits'),
                              style: const TextStyle(
                                  color: ThixPolicy.textSecondary,
                                  fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () => _openPicker(
                                  selected, all, aisleNumber, depts),
                              icon: const Icon(Icons.add_rounded, size: 18),
                              label: Text(_tr(l10n, 'sm_add_products',
                                  'Ajouter des produits')),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: selected.color,
                                foregroundColor: Colors.white,
                                elevation: 0,
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: inDept.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final p = inDept[i];
                        return _ProductRow(
                          product: p,
                          accent: selected.color,
                          onRemove: () async {
                            HapticFeedback.mediumImpact();
                            await _service.unassignProduct(
                                p['id'].toString());
                            ref.invalidate(supermarketAllProductsProvider(
                                widget.supermarketId));
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: ThixPolicy.primary,
        foregroundColor: Colors.white,
        onPressed: () {
          final depts = ref.read(departmentsProvider(widget.supermarketId)).valueOrNull;
          final all = ref.read(supermarketAllProductsProvider(widget.supermarketId)).valueOrNull ?? [];
          if (depts == null || depts.isEmpty) return;
          final idx = depts.indexWhere((d) => d.id == _selectedDeptId);
          _openPicker(depts[idx], all, idx + 1, depts);
        },
        icon: const Icon(Icons.add_rounded),
        label: Text(_tr(l10n, 'sm_add', 'Ajouter')),
      ),
    );
  }

  // ── Sélecteur de produits (bottom sheet) ──
  void _openPicker(
    SupermarketDepartment dept,
    List<Map<String, dynamic>> all,
    int aisleNumber,
    List<SupermarketDepartment> depts,
  ) {
    String query = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: ThixPolicy.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final filtered = query.isEmpty
              ? all
              : all
                  .where((p) => (p['title']?.toString() ?? '')
                      .toLowerCase()
                      .contains(query.toLowerCase()))
                  .toList();

          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                      color: ThixPolicy.border,
                      borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(height: 12),
                Text(
                  '${dept.name} — Allée $aisleNumber',
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: ThixPolicy.textMain),
                ),
                const SizedBox(height: 10),
                TextField(
                  onChanged: (v) => setSheet(() => query = v),
                  decoration: InputDecoration(
                    hintText: 'Rechercher un produit...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    filled: true,
                    fillColor: ThixPolicy.surfaceSoft,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final p = filtered[i];
                      final pid = p['id'].toString();
                      final currentDept =
                          p['department_id']?.toString();
                      final inThisDept = currentDept == dept.id;
                      final inOtherDept = currentDept != null &&
                          currentDept.isNotEmpty &&
                          currentDept != dept.id;
                      final otherIdx = inOtherDept
                          ? depts.indexWhere((d) => d.id == currentDept)
                          : -1;

                      return ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: p['image_url'] != null
                              ? CachedNetworkImage(
                                  imageUrl: p['image_url'].toString(),
                                  width: 44, height: 44, fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) => _ph(),
                                )
                              : _ph(),
                        ),
                        title: Text(
                          p['title']?.toString() ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                        subtitle: inOtherDept
                            ? Text(
                                'Déjà dans Allée ${otherIdx + 1}',
                                style: TextStyle(
                                    fontSize: 11, color: ThixPolicy.warning),
                              )
                            : null,
                        trailing: inThisDept
                            ? const Icon(Icons.check_circle_rounded,
                                color: ThixPolicy.success, size: 22)
                            : IconButton(
                                icon: const Icon(Icons.add_circle_outline_rounded,
                                    color: ThixPolicy.primary, size: 24),
                                onPressed: () async {
                                  HapticFeedback.mediumImpact();
                                  await _service.assignProductToDepartment(
                                      pid, dept.id, aisleNumber);
                                  ref.invalidate(
                                      supermarketAllProductsProvider(
                                          widget.supermarketId));
                                  Navigator.pop(ctx);
                                },
                              ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _ph() => Container(
        width: 44, height: 44, color: ThixPolicy.surfaceSoft,
        child: const Icon(Icons.image_outlined,
            color: ThixPolicy.textMuted, size: 18),
      );

  String _tr(AppLocalizations l10n, String key, String fb) {
    final v = l10n.t(key);
    return (v.isEmpty || v == key) ? fb : v;
  }
}

class _ProductRow extends StatelessWidget {
  final Map<String, dynamic> product;
  final Color accent;
  final VoidCallback onRemove;
  const _ProductRow({
    required this.product,
    required this.accent,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final price = (product['price'] as num?)?.toDouble() ?? 0;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: ThixPolicy.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: product['image_url'] != null
                ? CachedNetworkImage(
                    imageUrl: product['image_url'].toString(),
                    width: 52, height: 52, fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(
                        width: 52, height: 52, color: ThixPolicy.surfaceSoft),
                  )
                : Container(
                    width: 52, height: 52, color: ThixPolicy.surfaceSoft),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product['title']?.toString() ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  '${price.toInt()} ${product['currency'] ?? ''}',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: accent),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline_rounded,
                color: ThixPolicy.danger, size: 22),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}
