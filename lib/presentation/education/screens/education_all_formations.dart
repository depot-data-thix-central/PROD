import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/category.dart';

// ✅ CORRIGÉ : Le bon chemin d'importation (sans le "s" à provider)
import 'package:thix_id/presentation/education/providers/education_provider.dart'; 

import '../widgets/common/education_category_chip.dart';
import '../widgets/common/education_loading_shimmer.dart';
import '../widgets/common/formation_card.dart';

class EducationAllFormations extends ConsumerStatefulWidget {
  const EducationAllFormations({super.key});
  @override
  ConsumerState<EducationAllFormations> createState() => _EducationAllFormationsState();
}

class _EducationAllFormationsState extends ConsumerState<EducationAllFormations> {
  String _selectedCategory = 'all';
  String _selectedLevel = 'all';
  final _scrollController = ScrollController();

  Category get _allCategory => Category(id: 'all', name: 'Tous', icon: null, createdAt: DateTime.now(), formations: null);

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels > _scrollController.position.maxScrollExtent - 300) {
        ref.read(formationsProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final formationsAsync = ref.watch(formationsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFF),
      appBar: AppBar(
        title: const Text('Toutes les formations', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E))),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1A1A2E)), onPressed: () => Navigator.pop(context)),
        actions: [IconButton(icon: const Icon(Icons.filter_list_rounded, color: Color(0xFF1A1A2E)), onPressed: _showFilterDialog)],
      ),
      body: formationsAsync.when(
        loading: () => const EducationLoadingShimmer(),
        error: (e, _) => Center(child: Text('Erreur: $e')),
        data: (paginated) {
          return Column(children: [
            SizedBox(height: 40, child: categoriesAsync.when(
              data: (categories) => ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: categories.length + 1,
                itemBuilder: (context, index) {
                  final cat = index == 0 ? _allCategory : categories[index - 1];
                  final isSelected = _selectedCategory == cat.id;
                  return Padding(padding: const EdgeInsets.only(right: 8), child: EducationCategoryChip(
                    label: cat.name,
                    isSelected: isSelected,
                    onTap: () {
                      setState(() => _selectedCategory = cat.id);
                      ref.read(formationsProvider.notifier).filter(
                        categoryId: cat.id == 'all' ? null : cat.id,
                        level: _selectedLevel == 'all' ? null : _selectedLevel,
                      );
                    },
                  ));
                },
              ),
              loading: () => const SizedBox(),
              error: (_,__) => const SizedBox(),
            )),
            const SizedBox(height: 8),
            Expanded(child: RefreshIndicator(
              onRefresh: () async => ref.invalidate(formationsProvider),
              child: paginated.items.isEmpty
               ? const Center(child: Text('Aucune formation disponible', style: TextStyle(color: Color(0xFF7386A8))))
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: paginated.items.length + (paginated.hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == paginated.items.length) {
                        return const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Center(child: CircularProgressIndicator(color: Color(0xFF2D6CDF))));
                      }
                      return Padding(padding: const EdgeInsets.only(bottom: 12), child: FormationCard(formation: paginated.items[index], onTap: () => context.push('/education/formation/${paginated.items[index].id}')));
                    },
                  ),
            )),
          ]);
        },
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(context: context, builder: (context) => AlertDialog(
      title: const Text('Filtrer', style: TextStyle(fontWeight: FontWeight.w800)),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Niveau', style: TextStyle(fontWeight: FontWeight.w700)), const SizedBox(height: 8),
        Wrap(spacing: 8, children: [
          _buildLevelChip('all', 'Tous'),
          _buildLevelChip('beginner', 'Débutant'),
          _buildLevelChip('intermediate', 'Intermédiaire'),
          _buildLevelChip('advanced', 'Avancé'),
        ]),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Appliquer'))],
    ));
  }

  Widget _buildLevelChip(String value, String label) {
    final isSelected = _selectedLevel == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        setState(() => _selectedLevel = value);
        ref.read(formationsProvider.notifier).filter(
          categoryId: _selectedCategory == 'all' ? null : _selectedCategory,
          level: value == 'all' ? null : value,
        );
        Navigator.pop(context);
      },
      selectedColor: const Color(0xFF2D6CDF).withOpacity(0.1),
      checkmarkColor: const Color(0xFF2D6CDF),
    );
  }
}
