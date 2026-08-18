// lib/presentation/mon_pays/cards/ministry_card.dart
// Carte d'un Ministère

import 'package:flutter/material.dart';
import '../models/ministry.dart';
import '../utils/helpers.dart';

class MinistryCard extends StatelessWidget {
  final Ministry ministry;
  final VoidCallback onTap;

  const MinistryCard({
    required this.ministry,
    required this.onTap,
    super.key,
  });

  // ============================================================
  // CHARTE THIX ID — Design Institutionnel Premium (Navy / Bleu / Or)
  // ============================================================
  static const Color navyDeep = Color(0xFF0A1F44);
  static const Color navy = Color(0xFF123B7A);
  static const Color gold = Color(0xFFE3B23C);
  static const Color ivory = Color(0xFFF6F7FB);
  static const Color pureWhite = Color(0xFFFFFFFF);
  static const Color darkText = Color(0xFF10182B);
  static const Color mutedText = Color(0xFF6B7690);
  static const Color hairline = Color(0xFFE7EAF3);

  @override
  Widget build(BuildContext context) {
    final hasMinister = ministry.minister != null && ministry.minister!.isNotEmpty;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: pureWhite,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: hairline),
          boxShadow: [
            BoxShadow(color: navyDeep.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 5)),
          ],
        ),
        child: Row(
          children: [
            // ============================================================
            // ICÔNE/LOGO — carré arrondi navy cerclé or (institution ≠ personne)
            // ============================================================
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: navyDeep,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: gold, width: 1.6),
                image: ministry.imageUrl != null && ministry.imageUrl!.isNotEmpty
                    ? DecorationImage(image: NetworkImage(ministry.imageUrl!), fit: BoxFit.cover)
                    : null,
              ),
              alignment: Alignment.center,
              child: ministry.imageUrl == null || ministry.imageUrl!.isEmpty
                  ? Text(
                      MonPaysHelpers.getInitials(ministry.name),
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white),
                    )
                  : null,
            ),
            const SizedBox(width: 13),

            // ============================================================
            // NOM + MINISTRE / DESCRIPTION
            // ============================================================
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ministry.name,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: darkText),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  if (hasMinister)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: ivory, borderRadius: BorderRadius.circular(20)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.person_rounded, size: 11, color: navy),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              ministry.minister!,
                              style: const TextStyle(fontSize: 10.5, color: navy, fontWeight: FontWeight.w700),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Text(
                      ministry.description,
                      style: const TextStyle(fontSize: 11.5, color: mutedText, fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 6),

            // ============================================================
            // CHEVRON
            // ============================================================
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(color: ivory, shape: BoxShape.circle),
              child: const Icon(Icons.chevron_right_rounded, size: 18, color: navy),
            ),
          ],
        ),
      ),
    );
  }
}
