// lib/presentation/thix_event/admin/widgets/admin_app_bar.dart
import 'package:flutter/material.dart';
import '../core/admin_constants.dart';
import '../core/admin_guards.dart';

class AdminAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final bool showBack;

  const AdminAppBar({super.key, required this.title, this.actions, this.showBack = true});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: const Color(0xFF0A1F44),
      elevation: 0,
      leading: showBack? IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)) : null,
      title: Row(children: [
        Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: const Color(0xFFE3B23C), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.shield, size: 16, color: Color(0xFF0A1F44))),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
          if (AdminConstants.isDevOpenAccess) const Text('DEV • OPEN ACCESS', style: TextStyle(color: Colors.orangeAccent, fontSize: 8, fontWeight: FontWeight.w800))
        ])
      ]),
      actions: actions,
    );
  }

  @override Size get preferredSize => const Size.fromHeight(56);
}
