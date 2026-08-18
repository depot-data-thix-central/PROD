// lib/presentation/education/widgets/forum/forum_topic_card.dart
import 'package:flutter/material.dart';
import 'package:thix_id/presentation/education/models/forum_topic.dart';

class ForumTopicCard extends StatelessWidget {
  final ForumTopic topic;
  final VoidCallback onTap;

  const ForumTopicCard({
    super.key,
    required this.topic,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isClosed = topic.status == 'closed';
    final replyCount = topic.replies?.length ?? 0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isClosed ? Colors.grey[200]! : const Color(0xFF2D6CDF).withOpacity(0.2),
            width: isClosed ? 1 : 2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0A1F44).withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    topic.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isClosed ? const Color(0xFF7386A8) : const Color(0xFF1A1A2E),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isClosed)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Fermé',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF7386A8),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              topic.content,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF7386A8),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.person_outline_rounded, size: 14, color: Color(0xFF7386A8)),
                const SizedBox(width: 4),
                Text(
                  topic.authorName ?? 'Utilisateur',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF7386A8)),
                ),
                const Spacer(),
                const Icon(Icons.comment_rounded, size: 14, color: Color(0xFF7386A8)),
                const SizedBox(width: 4),
                Text(
                  '$replyCount',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF7386A8)),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.access_time_rounded, size: 14, color: Color(0xFF7386A8)),
                const SizedBox(width: 4),
                Text(
                  _formatDate(topic.createdAt), // ✅ Accepte DateTime?
                  style: const TextStyle(fontSize: 12, color: Color(0xFF7386A8)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ✅ Méthode corrigée pour accepter DateTime? et gérer null
  String _formatDate(DateTime? date) {
    if (date == null) return '—';
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
