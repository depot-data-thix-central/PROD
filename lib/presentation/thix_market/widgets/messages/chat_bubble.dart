// lib/presentation/thix_market/widgets/chat/chat_bubble.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ChatBubble extends StatelessWidget {
  final String message;
  final bool isMe;
  final DateTime timestamp;
  final String? imageUrl;
  final String? audioUrl;
  final String? status; // 'sending', 'sent', 'delivered', 'read'
  final VoidCallback? onImageTap;
  final VoidCallback? onAudioTap;

  const ChatBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.timestamp,
    this.imageUrl,
    this.audioUrl,
    this.status,
    this.onImageTap,
    this.onAudioTap,
  });

  // Couleurs de l'application
  static const Color navy = Color(0xFF1B2A4A);
  static const Color gold = Color(0xFFC9962C);
  static const Color danger = Color(0xFFE53935);
  static const Color textMuted = Color(0xFF8A8FA3);
  static const Color bgApp = Color(0xFFF6F7FB);

  @override
  Widget build(BuildContext context) {
    final isSending = status == 'sending';
    final isSent = status == 'sent';
    final isDelivered = status == 'delivered';
    final isRead = status == 'read';

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Material(
              elevation: 0,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isMe ? 16 : 4),
                bottomRight: Radius.circular(isMe ? 4 : 16),
              ),
              color: isMe ? navy : Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Image
                    if (imageUrl != null && imageUrl!.isNotEmpty)
                      GestureDetector(
                        onTap: onImageTap,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: imageUrl!,
                            height: 150,
                            width: 200,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              height: 150,
                              width: 200,
                              color: Colors.grey[200],
                              child: const Center(
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                            errorWidget: (_, __, ___) => Container(
                              height: 150,
                              width: 200,
                              color: Colors.grey[200],
                              child: const Icon(Icons.broken_image, size: 40, color: Colors.grey),
                            ),
                          ),
                        ),
                      ),
                    if (imageUrl != null && imageUrl!.isNotEmpty)
                      const SizedBox(height: 8),

                    // Audio
                    if (audioUrl != null && audioUrl!.isNotEmpty)
                      _buildAudioPlayer(context),
                    if (audioUrl != null && audioUrl!.isNotEmpty)
                      const SizedBox(height: 8),

                    // Message texte
                    if (message.isNotEmpty)
                      Text(
                        message,
                        style: TextStyle(
                          color: isMe ? Colors.white : navy,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),

            // Pied : heure et statut
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DateFormat('HH:mm').format(timestamp),
                  style: TextStyle(fontSize: 10, color: textMuted),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  if (isSending)
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 1.5),
                    )
                  else if (isSent)
                    Icon(Icons.check, size: 12, color: textMuted)
                  else if (isDelivered)
                    Icon(Icons.done_all, size: 12, color: textMuted)
                  else if (isRead)
                    Icon(Icons.done_all, size: 12, color: gold),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAudioPlayer(BuildContext context) {
    return GestureDetector(
      onTap: onAudioTap,
      child: Container(
        width: 200,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isMe
              ? Colors.white.withOpacity(0.15)
              : bgApp,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(
              Icons.play_arrow_rounded,
              size: 24,
              color: isMe ? Colors.white : navy,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: 0.3,
                  backgroundColor: isMe
                      ? Colors.white.withOpacity(0.3)
                      : Colors.grey[300],
                  color: isMe ? Colors.white : gold,
                  minHeight: 4,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '0:30 / 1:00',
              style: TextStyle(
                fontSize: 10,
                color: isMe ? Colors.white70 : textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
