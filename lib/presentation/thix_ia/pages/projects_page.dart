// lib/presentation/thix_ia/pages/projects_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/thix_design_policy.dart';
import '../providers/thix_ia_provider.dart';
import '../providers/project_provider.dart';
import '../widgets/project_card.dart';
import '../widgets/empty_state_widget.dart';

// Ajout du provider manquant pour la barre de recherche
final projectSearchQueryProvider = StateProvider<String>((ref) => '');

class ProjectsPage extends ConsumerStatefulWidget {
  const ProjectsPage({super.key});
  @override
  ConsumerState<ProjectsPage> createState() => _ProjectsPageState();
}

class _ProjectsPageState extends ConsumerState<ProjectsPage> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        ref.read(projectsProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = ref.watch(filteredProjectsProvider);
    final projectsAsync = ref.watch(projectsProvider);

    return Scaffold(
      backgroundColor: ThixPolicy.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text('Mes Projets', style: ThixPolicy.h3Style),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(ThixPolicy.s16),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => ref.read(projectSearchQueryProvider.notifier).state = v,
              decoration: InputDecoration(
                hintText: 'Rechercher THX-BIZ-...',
                prefixIcon: const Icon(Icons.search_rounded, color: ThixPolicy.textMuted),
                filled: true,
                fillColor: ThixPolicy.surfaceStrong,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(ThixPolicy.rMd), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
        ),
      ),
      body: projectsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: ThixPolicy.primary)),
        error: (e, _) => Center(child: Text('Erreur $e')),
        data: (_) {
          if (filtered.isEmpty) {
            return EmptyStateWidget(
              icon: Icons.search_off_rounded,
              title: 'Aucun projet trouvé',
              subtitle: 'Essayez un autre terme ou créez un nouveau projet.',
              actionLabel: 'Créer un projet',
              onAction: () => context.push('/thix-ia/create'),
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.read(projectsProvider.notifier).refresh(),
            child: ListView.builder(
              controller: _scrollController,
              itemCount: filtered.length + 1,
              itemBuilder: (_, i) {
                if (i == filtered.length) {
                  return Padding(padding: const EdgeInsets.all(16), child: Center(child: Text('${filtered.length} projets', style: ThixPolicy.captionStyle)));
                }
                final p = filtered[i];
                return ProjectCard(
                  project: p,
                  onTap: () => context.push('/thix-ia/project/${p.projectCode}'),
                  onLongPress: () async {
                    await ref.read(activeProjectProvider.notifier).setActive(p.projectCode);
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${p.projectCode} défini comme actif')));
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}
