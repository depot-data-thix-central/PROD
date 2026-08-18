// ============================================================
// 📁 lib/presentation/chat/settings/widgets/chat_settings_section.dart
// ============================================================

import 'package:flutter/material.dart';

class ChatSettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const ChatSettingsSection({
    super.key,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              letterSpacing: 0.5,
            ),
          ),
        ),
        ...children,
        const Divider(height: 1),
      ],
    );
  }
}
