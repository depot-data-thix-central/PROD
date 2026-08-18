import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/chat/sentiment.dart';

class _C {
  static const bg = Colors.white;
  static const border = Color(0xFFE2E8F0);
  static const textMain = Color(0xFF0F172A);
  static const textMuted = Color(0xFF64748B);
}

// Provider scalable si analyse sentiment asynchrone future
final sentimentProvider = Provider.family<SentimentResult?, String>((ref, messageId) => null);

class SentimentIndicator extends ConsumerWidget {
  final SentimentResult? result;
  final bool showLabel;
  final double size;

  const SentimentIndicator({
    super.key,
    required this.result,
    this.showLabel = true,
    this.size = 20,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (result == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: result!.color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: result!.color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(result!.icon, color: result!.color, size: size),
          if (showLabel) ...[
            const SizedBox(width: 5),
            Text(
              result!.labelFr,
              style: TextStyle(
                color: result!.color,
                fontSize: size * 0.58,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
