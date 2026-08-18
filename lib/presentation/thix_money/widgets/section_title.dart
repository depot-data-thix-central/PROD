// lib/presentation/thix_money/widgets/section_title.dart
import 'package:flutter/material.dart';

class SectionTitle extends StatelessWidget {
  final String title;
  final VoidCallback? onViewAll;
  const SectionTitle({super.key, required this.title, this.onViewAll});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F1D5E))),
        if (onViewAll!= null) TextButton(onPressed: onViewAll, child: const Text('Voir tout >', style: TextStyle(fontSize: 12))),
      ]),
    );
  }
}
