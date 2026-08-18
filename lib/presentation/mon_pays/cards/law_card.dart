// lib/presentation/mon_pays/cards/law_card.dart
// Carte pour afficher une loi dans les listes

import 'package:flutter/material.dart';

class LawCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? date;
  final String? category;
  final VoidCallback onTap;

  const LawCard({
    required this.title,
    this.subtitle,
    this.date,
    this.category,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: const Icon(Icons.gavel, color: Color(0xFF1A5276)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (subtitle != null) Text(subtitle!),
            if (date != null) Text(date!, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}
