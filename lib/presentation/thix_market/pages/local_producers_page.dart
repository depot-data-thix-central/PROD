// ============================================================================
// PAGE PRODUCTEURS — COOPÉRATIVES UNIQUEMENT (aucune autre boutique)
// ============================================================================
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/african_countries.dart';
import '../core/drc_portal_theme.dart';
import '../providers/local_moderation_providers.dart';

class LocalProducersPage extends ConsumerWidget {
  const LocalProducersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(localCooperativesProvider);
    final myShop = ref.watch(localMyShopProvider).valueOrNull;
    final logged = Supabase.instance.client.auth.currentUser != null;

    return Scaffold(
      backgroundColor: kDrcBg,
      appBar: AppBar(
        backgroundColor: kDrcBlueDeep,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: const Text('Coopératives & producteurs', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
      ),
      floatingActionButton: (logged && myShop == null)
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/market/local/vendor-space'),
              backgroundColor: kDrcBlue,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_business_rounded, size: 18),
              label: const Text('Devenir coopérative', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
            )
          : null,
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator(color: kDrcBlue)),
        error: (_, __) => const Center(child: Text('Erreur de chargement')),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: const BoxDecoration(color: kDrcSoft, shape: BoxShape.circle),
                      child: Icon(Icons.agriculture_rounded, size: 40, color: kDrcBlue.withOpacity(0.6)),
                    ),
                    const SizedBox(height: 14),
                    const Text('Aucune coopérative enregistrée', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: kDrcInk)),
                    const SizedBox(height: 6),
                    Text('Créez votre coopérative pour apparaître ici.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: kDrcSub)),
                  ],
                ),
              ),
            );
          }
          return RefreshIndicator(
            color: kDrcBlue,
            onRefresh: () async => ref.invalidate(localCooperativesProvider),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _card(context, list[i]),
            ),
          );
        },
      ),
    );
  }

  Widget _card(BuildContext context, Map<String, dynamic> p) {
    final id = p['id']?.toString() ?? '';
    final logo = p['logo_url']?.toString();
    final hasLogo = logo != null && logo.startsWith('http');
    final name = (p['name'] ?? '').toString();
    final city = AfricanCountries.locationLine(city: (p['city'] ?? '').toString(), code: p['country']?.toString());
    final count = p['local_count'] ?? 0;

    return GestureDetector(
      onTap: () {
        if (id.isNotEmpty) context.push('/market/shop/$id');
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kDrcLine),
          boxShadow: [BoxShadow(color: kDrcBlueDeep.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 5))],
        ),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: kDrcSoft,
                border: Border.all(color: kDrcBlue.withOpacity(0.25), width: 1.5),
                image: hasLogo ? DecorationImage(image: CachedNetworkImageProvider(logo), fit: BoxFit.cover) : null,
              ),
              child: !hasLogo ? const Icon(Icons.agriculture_rounded, color: kDrcBlue, size: 26) : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14.5, color: kDrcInk)),
                  const SizedBox(height: 3),
                  Row(children: [
                    const Icon(Icons.location_on_rounded, size: 11, color: kDrcRed),
                    const SizedBox(width: 3),
                    Expanded(child: Text(city, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: kDrcSub))),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    _tag('Coopérative vérifiée', kDrcBlue, icon: Icons.verified_rounded),
                    const SizedBox(width: 6),
                    _tag('$count produits', kDrcBlueDeep),
                  ]),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: kDrcSub, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _tag(String label, Color color, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: color.withOpacity(0.10), borderRadius: BorderRadius.circular(6)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 9, color: color), const SizedBox(width: 3)],
        Text(label, style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, color: color)),
      ]),
    );
  }
}
