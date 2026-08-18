// lib/presentation/education/pages/forum_topic_detail_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../models/forum_topic.dart';
import '../../../providers/forum_provider.dart';
import '../widgets/common/education_empty_state.dart';
import '../widgets/forum/forum_reply_widget.dart';

class ForumTopicDetailPage extends StatefulWidget {
  final String topicId;

  const ForumTopicDetailPage({super.key, required this.topicId});

  @override
  State<ForumTopicDetailPage> createState() => _ForumTopicDetailPageState();
}

class _ForumTopicDetailPageState extends State<ForumTopicDetailPage> {
  ForumTopic? _topic;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final provider = context.read<ForumProvider>();
    await provider.loadTopicReplies(widget.topicId);
    final topics = provider.topics;
    final topic = topics.firstWhere(
      (t) => t.id == widget.topicId,
      orElse: () => ForumTopic(
        id: '',
        formationId: '',
        userId: '',
        title: '',
        body: '',
        status: 'open',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    setState(() {
      _topic = topic.id.isNotEmpty ? topic : null;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ForumProvider>();
    final replies = provider.replies;

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_topic == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: EducationEmptyState(
          title: 'Sujet introuvable',
          subtitle: 'Ce sujet de forum n\'existe pas.',
          icon: Icons.forum_rounded,
          buttonText: 'Retour',
          onButtonPressed: () => context.pop(),
        ),
      );
    }

    final isClosed = _topic!.status == 'closed';
    final userId = Supabase.instance.client.auth.currentUser?.id;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          _topic!.title,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (!isClosed && userId == _topic!.userId)
            IconButton(
              icon: const Icon(Icons.close_rounded, color: Color(0xFFFF5B3D)),
              onPressed: _closeTopic,
            ),
        ],
      ),
      body: Column(
        children: [
          // Message initial du topic
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _topic!.body,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.person_outline_rounded, size: 14, color: Color(0xFF7386A8)),
                    const SizedBox(width: 4),
                    Text(
                      _topic!.authorName ?? 'Utilisateur',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF7386A8)),
                    ),
                    const Spacer(),
                    Text(
                      _formatDate(_topic!.createdAt),
                      style: const TextStyle(fontSize: 12, color: Color(0xFF7386A8)),
                    ),
                  ],
                ),
                if (isClosed)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Ce sujet est fermé',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF7386A8),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Liste des réponses
          Expanded(
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : replies.isEmpty
                    ? const Center(
                        child: Text(
                          'Aucune réponse pour le moment.',
                          style: TextStyle(color: Color(0xFF7386A8)),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: replies.length,
                        itemBuilder: (context, index) {
                          final reply = replies[index];
                          return ForumReplyWidget(
                            reply: reply,
                            isCurrentUser: reply.userId == userId,
                          );
                        },
                      ),
          ),
          // Zone de saisie (si ouvert)
          if (!isClosed)
            _buildReplyInput(),
        ],
      ),
    );
  }

  Widget _buildReplyInput() {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return const SizedBox();

    final TextEditingController controller = TextEditingController();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A1F44).withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: 'Écrire une réponse...',
                hintStyle: const TextStyle(color: Color(0xFF7386A8)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: const Color(0xFFF0F7FF),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: const Color(0xFF2D6CDF),
            child: IconButton(
              icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
              onPressed: () async {
                final text = controller.text.trim();
                if (text.isEmpty) return;
                final provider = context.read<ForumProvider>();
                final success = await provider.createReply(
                  topicId: widget.topicId,
                  userId: userId,
                  body: text,
                );
                if (success != null) {
                  controller.clear();
                  await _loadData();
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  void _closeTopic() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Fermer le sujet'),
        content: const Text('Êtes-vous sûr de vouloir fermer ce sujet ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFFF5B3D)),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final provider = context.read<ForumProvider>();
      await provider.closeTopic(widget.topicId);
      await _loadData();
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays > 0) {
      return 'il y a ${diff.inDays}j';
    } else if (diff.inHours > 0) {
      return 'il y a ${diff.inHours}h';
    } else if (diff.inMinutes > 0) {
      return 'il y a ${diff.inMinutes}m';
    } else {
      return 'à l\'instant';
    }
  }
}
