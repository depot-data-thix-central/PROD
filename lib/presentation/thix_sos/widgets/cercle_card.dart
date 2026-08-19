/// THIX SOS — Carte cercle de secours 1/2/3 (production)
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/sos_models.dart';

class CercleCard extends StatelessWidget {
  const CercleCard({
    super.key,
    required this.circle,
    required this.contacts,
    this.onTap,
    this.onManage,
  });

  final int circle; // 1, 2, 3
  final List<SosContact> contacts;
  final VoidCallback? onTap;
  final VoidCallback? onManage;

  Color get _color {
    switch (circle) {
      case 1:
        return const Color(0xFF10B981);
      case 2:
        return const Color(0xFFF59E0B);
      case 3:
        return const Color(0xFF3B82F6);
      default:
        return Colors.grey;
    }
  }

  String get _title {
    switch (circle) {
      case 1:
        return 'Cercle 1 – Prioritaire';
      case 2:
        return 'Cercle 2 – Secondaire';
      case 3:
        return 'Cercle 3 – Urgence';
      default:
        return 'Cercle $circle';
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = contacts.length;
    final preview = contacts.take(3).toList();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF16161F),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            children: [
              // Badge numéro
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: _color.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    '$circle',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: _color,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Titre + count
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _title,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      count == 0
                          ? 'Aucun secours'
                          : '$count secours',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.white38,
                      ),
                    ),
                  ],
                ),
              ),

              // Avatars empilés
              if (preview.isNotEmpty)
                SizedBox(
                  width: 12.0 + preview.length * 18.0,
                  height: 28,
                  child: Stack(
                    children: [
                      for (var i = 0; i < preview.length; i++)
                        Positioned(
                          left: i * 16.0,
                          child: _Avatar(
                            name: preview[i].name,
                            photoUrl: preview[i].photoUrl,
                            index: i,
                          ),
                        ),
                    ],
                  ),
                ),

              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: Colors.white24, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.name,
    this.photoUrl,
    required this.index,
  });

  final String name;
  final String? photoUrl;
  final int index;

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name.characters.first.toUpperCase() : '?';
    final colors = [
      const Color(0xFF6366F1),
      const Color(0xFFEC4899),
      const Color(0xFF14B8A6),
      const Color(0xFFF97316),
    ];

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF16161F), width: 2),
      ),
      child: CircleAvatar(
        radius: 12,
        backgroundColor: colors[index % colors.length],
        backgroundImage:
            photoUrl != null && photoUrl!.isNotEmpty ? NetworkImage(photoUrl!) : null,
        child: photoUrl == null || photoUrl!.isEmpty
            ? Text(
                initial,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              )
            : null,
      ),
    );
  }
}

/// Liste des 3 cercles prête à brancher sur Riverpod
class CerclesList extends StatelessWidget {
  const CerclesList({
    super.key,
    required this.contacts,
    this.onCircleTap,
    this.onManage,
  });

  final List<SosContact> contacts;
  final void Function(int circle)? onCircleTap;
  final VoidCallback? onManage;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'MES SECOURS',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white54,
                letterSpacing: 0.6,
              ),
            ),
            if (onManage != null)
              GestureDetector(
                onTap: onManage,
                child: Text(
                  'Gérer',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF60A5FA),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        for (final circle in [1, 2, 3]) ...[
          CercleCard(
            circle: circle,
            contacts: contacts.where((c) => c.circle == circle).toList(),
            onTap: onCircleTap != null ? () => onCircleTap!(circle) : null,
          ),
          if (circle < 3) const SizedBox(height: 8),
        ],
      ],
    );
  }
}
