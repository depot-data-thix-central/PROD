import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// ✅ CORRIGÉ : Le bon chemin d'importation (sans le "s" à provider)
import 'package:thix_id/presentation/education/providers/education_provider.dart'; 

import '../widgets/common/education_empty_state.dart';
import '../widgets/common/formation_card.dart';

class EducationSearchPage extends ConsumerStatefulWidget {
  const EducationSearchPage({super.key});
  @override
  ConsumerState<EducationSearchPage> createState() => _EducationSearchPageState();
}

class _EducationSearchPageState extends ConsumerState<EducationSearchPage> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels > _scrollController.position.maxScrollExtent - 300) {
        ref.read(searchFormationsProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchAsync = ref.watch(searchFormationsProvider);
    final notifier = ref.read(searchFormationsProvider.notifier);

    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1A1A2E)), onPressed: () => context.pop()),
        title: Container(
          height: 44,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[200]!)),
          child: Row(children: [
            const SizedBox(width: 12),
            const Icon(Icons.search_rounded, color: Color(0xFF7386A8)),
            const SizedBox(width: 8),
            Expanded(child: TextField(
              controller: _searchController,
              focusNode: _focusNode,
              autofocus: true,
              decoration: const InputDecoration(hintText: 'Rechercher une formation...', border: InputBorder.none, isDense: true, hintStyle: TextStyle(fontSize: 14, color: Color(0xFF7386A8))),
              onChanged: (v) => notifier.setQuery(v),
            )),
            if (_searchController.text.isNotEmpty)
              IconButton(icon: const Icon(Icons.clear_rounded, color: Color(0xFF7386A8), size: 18), onPressed: () { _searchController.clear(); notifier.clear(); _focusNode.requestFocus(); }),
            const SizedBox(width: 4),
          ]),
        ),
      ),
      body: searchAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF2D6CDF))),
        error: (e, _) => Center(child: Text('Erreur: $e')),
        data: (paginated) {
          final results = paginated.items;
          final query = notifier.query;

          if (query.isEmpty) {
            return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: const [
              Icon(Icons.search_rounded, size: 64, color: Color(0xFFD1D5DB)), SizedBox(height: 16),
              Text('Recherchez une formation', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E))), SizedBox(height: 8),
              Text('Tapez au moins 2 lettres', style: TextStyle(color: Color(0xFF7386A8))),
            ]));
          }

          if (results.isEmpty && !paginated.hasMore) {
            return EducationEmptyState(title: 'Aucun résultat', subtitle: 'Aucune formation pour "$query"', icon: Icons.search_off_rounded, buttonText: 'Effacer', onButtonPressed: () { _searchController.clear(); notifier.clear(); });
          }

          return ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: results.length + (paginated.hasMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == results.length) {
                return const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Center(child: CircularProgressIndicator(color: Color(0xFF2D6CDF))));
              }
              return Padding(padding: const EdgeInsets.only(bottom: 12), child: FormationCard(formation: results[index], onTap: () => context.push('/education/formation/${results[index].id}')));
            },
          );
        },
      ),
    );
  }
}
