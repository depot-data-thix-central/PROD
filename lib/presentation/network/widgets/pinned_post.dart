// lib/presentation/network/widgets/pinned_post.dart
import 'package:flutter/material.dart';
import 'package:thix_id/models/network_post.dart';

class PinnedPost extends StatelessWidget {
  final NetworkPost post;
  final VoidCallback onTap;
  final VoidCallback? onUnpin;

  const PinnedPost({
    super.key,
    required this.post,
    required this.onTap,
    this.onUnpin,
  });

  @override
  Widget build(BuildContext context) {
    final content = post.content ?? '';
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [const Color(0xFFD4AF37).withValues(alpha: 0.08), Colors.transparent],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.3)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4AF37).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.push_pin, size: 20, color: Color(0xFFD4AF37)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Épinglé', style: TextStyle(fontSize: 11, color: Color(0xFFD4AF37), fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(content.isNotEmpty ? content : 'Publication épinglée', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, height: 1.3)),
                    ],
                  ),
                ),
                if (onUnpin != null)
                  IconButton(icon: const Icon(Icons.close, size: 18, color: Colors.grey), onPressed: onUnpin, tooltip: 'Désépingler'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
