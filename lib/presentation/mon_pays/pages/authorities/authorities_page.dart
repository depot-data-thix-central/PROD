// lib/presentation/mon_pays/pages/authorities/authorities_page.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../utils/constants.dart';
import '../../providers/authorities_provider.dart';
import '../../cards/authority_card.dart';

class AuthoritiesPage extends HookConsumerWidget {
  final String? initialCategory;

  const AuthoritiesPage({super.key, this.initialCategory});

  // ─── Charte Graphique Institutionnelle ────────────────────────────
  static const Color primaryBlue = Color(0xFF0052A5); // Bleu Drapeau RDC
  static const Color gold = Color(0xFFF7C948); // Or RDC
  static const Color lightBg = Color(0xFFF4F7FB);
  static const Color pureWhite = Color(0xFFFFFFFF);
  static const Color darkText = Color(0xFF0F172A);
  static const Color mutedText = Color(0xFF5A6B87);
  static const Color hairline = Color(0xFFE2E8F0);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ─── 1. Gestion des états locaux (Hooks) ───────────────────────
    final searchCtrl = useTextEditingController();
    final searchQuery = useState<String>('');
    final selectedCategory = useState<String>(initialCategory ?? 'Tous');

    // ─── 2. Debounce (Sécurité Anti-Spam DB) ───────────────────────
    // Attend 500ms après la dernière frappe pour mettre à jour la recherche
    useEffect(() {
      Timer? timer;
      void listener() {
        timer?.cancel();
        timer = Timer(const Duration(milliseconds: 500), () {
          if (searchQuery.value != searchCtrl.text.trim()) {
            searchQuery.value = searchCtrl.text.trim();
          }
        });
      }
      searchCtrl.addListener(listener);
      return () {
        timer?.cancel();
        searchCtrl.removeListener(listener);
      };
    }, [searchCtrl]);

    // ─── 3. Création du paramètre Provider (Family) ────────────────
    final categoryParam = selectedCategory.value == 'Tous' ? null : selectedCategory.value;
    final searchParam = searchQuery.value.isEmpty ? null : searchQuery.value;

    final paginatedProvider = authoritiesPaginatedProvider(
      category: categoryParam,
      search: searchParam,
      activeOnly: true,
    );

    final paginatedState = ref.watch(paginatedProvider);

    // ─── 4. Gestion de la Pagination au Scroll ─────────────────────
    final scrollController = useScrollController();
    
    useEffect(() {
      void listener() {
        if (scrollController.position.pixels >= scrollController.position.maxScrollExtent - 200) {
          // Utilise le notifier spécifique à ces paramètres de recherche
          ref.read(paginatedProvider.notifier).loadNextPage();
        }
      }
      scrollController.addListener(listener);
      return () => scrollController.removeListener(listener);
    }, [scrollController, paginatedProvider]);

    // ─── BUILD DE L'UI ─────────────────────────────────────────────
    return Scaffold(
      backgroundColor: lightBg,
      appBar: _buildAppBar(context, ref, paginatedProvider),
      body: Column(
        children: [
          _buildHeaderSection(searchCtrl, selectedCategory),
          Expanded(
            child: RefreshIndicator(
              color: primaryBlue,
              backgroundColor: pureWhite,
              onRefresh: () async => ref.invalidate(paginatedProvider),
              child: paginatedState.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: primaryBlue),
                ),
                error: (error, _) => _buildErrorState(error, () => ref.invalidate(paginatedProvider)),
                data: (result) {
                  if (result.data.isEmpty) {
                    return _buildEmptyState();
                  }
                  
                  return ListView.separated(
                    controller: scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: result.data.length + (result.hasMore ? 1 : 0),
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      // Indicateur de chargement en bas de liste
                      if (index >= result.data.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(color: primaryBlue, strokeWidth: 2.5),
                            ),
                          ),
                        );
                      }

                      final authority = result.data[index];
                      return AuthorityCard(
                        authority: authority,
                        onTap: () {
                          context.push('/mon-pays/authorities/${authority.id}');
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Composants UI Institutionnels ──────────────────────────────

  PreferredSizeWidget _buildAppBar(BuildContext context, WidgetRef ref, ProviderBase provider) {
    return AppBar(
      backgroundColor: primaryBlue,
      elevation: 0,
      centerTitle: true,
      iconTheme: const IconThemeData(color: pureWhite),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.network(
            'https://upload.wikimedia.org/wikipedia/commons/thumb/e/e5/Coat_of_arms_of_the_Democratic_Republic_of_the_Congo.svg/200px-Coat_of_arms_of_the_Democratic_Republic_of_the_Congo.svg.png',
            height: 28,
            errorBuilder: (_, __, ___) => const Icon(Icons.shield, color: gold, size: 24),
          ),
          const SizedBox(width: 12),
          const Text(
            'AUTORITÉS',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: pureWhite,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: pureWhite),
          onPressed: () => ref.invalidate(provider),
          tooltip: 'Actualiser',
        ),
      ],
    );
  }

  Widget _buildHeaderSection(TextEditingController searchCtrl, ValueNotifier<String> selectedCategory) {
    return Container(
      decoration: BoxDecoration(
        color: pureWhite,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        children: [
          // Barre de recherche
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: lightBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: hairline),
              ),
              child: TextField(
                controller: searchCtrl,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                decoration: InputDecoration(
                  hintText: 'Rechercher une autorité (nom, fonction)...',
                  hintStyle: const TextStyle(color: mutedText, fontSize: 14),
                  prefixIcon: const Icon(Icons.search_rounded, color: primaryBlue, size: 20),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  suffixIcon: searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.cancel, color: mutedText, size: 18),
                          onPressed: () => searchCtrl.clear(),
                        )
                      : null,
                ),
              ),
            ),
          ),
          
          // Filtres de catégories
          SizedBox(
            height: 54,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: MonPaysConstants.authorityCategories.length,
              itemBuilder: (context, index) {
                final cat = MonPaysConstants.authorityCategories[index];
                final isSelected = cat == selectedCategory.value;
                
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  child: InkWell(
                    onTap: () => selectedCategory.value = cat,
                    borderRadius: BorderRadius.circular(20),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected ? primaryBlue : pureWhite,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? primaryBlue : hairline,
                        ),
                      ),
                      child: Text(
                        cat,
                        style: TextStyle(
                          color: isSelected ? pureWhite : darkText,
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
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 64, color: mutedText.withOpacity(0.5)),
          const SizedBox(height: 16),
          const Text(
            'Aucune autorité trouvée',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: darkText),
          ),
          const SizedBox(height: 8),
          const Text(
            'Essayez de modifier vos filtres de recherche.',
            style: TextStyle(color: mutedText, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(Object error, VoidCallback onRetry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: Colors.redAccent),
            const SizedBox(height: 16),
            const Text(
              'Impossible de charger les données',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              textAlign: TextAlign.center,
              style: const TextStyle(color: mutedText, fontSize: 12),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryBlue,
                foregroundColor: pureWhite,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
