// lib/presentation/thix_market/pages/department_products_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/presentation/thix_market/providers/supermarket_providers.dart';
import 'package:thix_id/presentation/thix_market/widgets/products/product_card.dart';

class DepartmentProductsPage extends ConsumerWidget {
  final String departmentId;
  final String departmentName;
  final int aisleNumber;
  final Color accentColor;

  const DepartmentProductsPage({
    super.key,
    required this.departmentId,
    required this.departmentName,
    required this.aisleNumber,
    required this.accentColor,
  });

  String _tr(AppLocalizations l10n, String key, String fb) {
    final v = l10n.t(key);
    return (v.isEmpty || v == key) ? fb : v;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final productsAsync =
        ref.watch(departmentProductsProvider(departmentId));

    return Scaffold(
      backgroundColor: ThixPolicy.surfaceSoft,
      appBar: AppBar(
        backgroundColor: accentColor,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(departmentName,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w900)),
            Text('Allée $aisleNumber',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withOpacity(0.8))),
          ],
        ),
      ),
      body: productsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (products) {
          if (products.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.inventory_2_outlined,
                      size: 48, color: accentColor.withOpacity(0.5)),
                  const SizedBox(height: 12),
                  Text(
                    _tr(l10n, 'sm_dept_empty',
                        'Rayon en réapprovisionnement'),
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: ThixPolicy.textSecondary),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(departmentProductsProvider(departmentId));
            },
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
              physics: const AlwaysScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.68,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: products.length,
              itemBuilder: (_, i) => ProductCard(
                product: products[i],
                onTap: (_) =>
                    context.push('/market/product/${products[i]['id']}'),
              ),
            ),
          );
        },
      ),
    );
  }
}
