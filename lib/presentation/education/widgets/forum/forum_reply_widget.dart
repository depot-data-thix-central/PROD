// lib/presentation/education/widgets/forum/forum_reply_widget.dart
import 'package:flutter/material.dart';
import '../../../models/forum_reply.dart';

class ForumReplyWidget extends StatelessWidget {
  final ForumReply reply;
  final bool isCurrentUser;

  const ForumReplyWidget({
    super.key,
    required this.reply,
    this.isCurrentUser = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCurrentUser ? const Color(0xFF2D6CDF).withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrentUser ? const Color(0xFF2D6CDF).withOpacity(0.2) : Colors.grey[200]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person_outline_rounded, size: 14, color: Color(0xFF7386A8)),
              const SizedBox(width: 4),
              Text(
                reply.authorName ?? 'Utilisateur',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              if (isCurrentUser)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2D6CDF).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Vous',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2D6CDF),
                      ),
                    ),
                  ),
                ),
              const Spacer(),
              Text(
                _formatDate(reply.createdAt),
                style: const TextStyle(fontSize: 11, color: Color(0xFF7386A8)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            reply.body,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF1A1A2E),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
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
