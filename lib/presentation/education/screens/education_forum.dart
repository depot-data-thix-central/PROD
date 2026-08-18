import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/forum_provider.dart';
import '../widgets/forum/forum_topic_card.dart';
import '../widgets/forum/forum_create_topic_dialog.dart';
import '../widgets/common/education_empty_state.dart';

class EducationForum extends ConsumerStatefulWidget {
  final String formationId;
  const EducationForum({super.key, required this.formationId});
  @override
  ConsumerState<EducationForum> createState() => _EducationForumState();
}

class _EducationForumState extends ConsumerState<EducationForum> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels > _scrollController.position.maxScrollExtent - 300) {
        ref.read(forumTopicsProvider(widget.formationId).notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _openCreate() {
    showDialog(
      context: context,
      builder: (_) => ForumCreateTopicDialog(formationId: widget.formationId),
    ).then((created) {
      if (created == true) ref.invalidate(forumTopicsProvider(widget.formationId));
    });
  }

  @override
  Widget build(BuildContext context) {
    final topicsAsync = ref.watch(forumTopicsProvider(widget.formationId));

    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFF),
      appBar: AppBar(
        title: const Text('Forum', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E))),
        backgroundColor: Colors.white, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1A1A2E)), onPressed: () => context.pop()),
        actions: [IconButton(icon: const Icon(Icons.add_rounded, color: Color(0xFF1A1A2E)), onPressed: _openCreate)],
      ),
      body: topicsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF2D6CDF))),
        error: (e, _) => Center(child: Text('Erreur: $e')),
        data: (paginated) {
          if (paginated.items.isEmpty) {
            return EducationEmptyState(
              title: 'Aucun sujet',
              subtitle: 'Soyez le premier à poser une question',
              icon: Icons.forum_rounded,
              buttonText: 'Créer un sujet',
              onButtonPressed: _openCreate,
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(forumTopicsProvider(widget.formationId)),
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: paginated.items.length + (paginated.hasMore? 1 : 0),
              itemBuilder: (context, index) {
                if (index == paginated.items.length) {
                  return const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Center(child: CircularProgressIndicator()));
                }
                final topic = paginated.items[index];
                return Padding(padding: const EdgeInsets.only(bottom: 12), child: ForumTopicCard(topic: topic, onTap: () => context.push('/education/forum/topic/${topic.id}')));
              },
            ),
          );
        },
      ),
    );
  }
}
