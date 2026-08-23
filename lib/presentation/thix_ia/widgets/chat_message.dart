// lib/presentation/thix_ia/widgets/chat_message.dart
import 'package:flutter/material.dart';
import '../../../../core/theme/thix_design_policy.dart';
import '../models/project_memory.dart';
import 'package:thix_id/presentation/thix_ia/models/chat_message.dart';
class ChatMessageWidget extends StatelessWidget {
  const ChatMessageWidget({super.key, required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    final isSystem = message.role == 'system';

    if (isSystem) {
      return Container(
        margin: EdgeInsets.symmetric(vertical: 8),
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: ThixPolicy.info.withOpacity(0.08), borderRadius: BorderRadius.circular(20), border: Border.all(color: ThixPolicy.info.withOpacity(0.15))),
        child: Row(children: [Icon(Icons.info_outline_rounded, size: 14, color: ThixPolicy.info), SizedBox(width: 6), Expanded(child: Text(message.content, style: ThixPolicy.captionStyle.copyWith(color: ThixPolicy.info)))]),
      );
    }

    return Align(
      alignment: isUser? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(bottom: 12, left: isUser? 48 : 0, right: isUser? 0 : 48),
        padding: EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isUser? ThixPolicy.primary : Colors.white,
          borderRadius: BorderRadius.only(topLeft: Radius.circular(ThixPolicy.rLg), topRight: Radius.circular(ThixPolicy.rLg), bottomLeft: Radius.circular(isUser? ThixPolicy.rLg : 4), bottomRight: Radius.circular(isUser? 4 : ThixPolicy.rLg)),
          border: isUser? null : Border.all(color: ThixPolicy.border),
          boxShadow: ThixPolicy.shadowCard(opacity: 0.04),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isUser)...[
              Row(children: [Container(width: 20, height: 20, decoration: BoxDecoration(color: ThixPolicy.primary.withOpacity(0.12), shape: BoxShape.circle), child: Icon(Icons.auto_awesome_rounded, size: 12, color: ThixPolicy.primary)), SizedBox(width: 6), Text('THIX IA', style: ThixPolicy.microStyle.copyWith(fontWeight: ThixPolicy.bold, color: ThixPolicy.primary))]),
              SizedBox(height: 8),
            ],
            Text(message.content, style: ThixPolicy.bodySmallStyle.copyWith(color: isUser ? Colors.white : Colors.black87, height: 1.4)),

            if (message.isStreaming)...[
              SizedBox(height: 8),
              SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: isUser? Colors.white : ThixPolicy.primary)),
            ],
            if (message.metadata!= null && message.metadata!['sources']!= null)...[
              SizedBox(height: 8),
              Wrap(spacing: 6, children: (message.metadata!['sources'] as List).map((s) => Container(padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: ThixPolicy.surfaceStrong, borderRadius: BorderRadius.circular(12)), child: Text(s.toString(), style: ThixPolicy.microStyle.copyWith(fontSize: 8)))).toList()),
            ],
          ],
        ),
      ),
    );
  }
}
