// lib/presentation/mon_pays/cards/authority_card.dart
// Carte d'une autorité pour les listes

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/authority.dart';
import '../providers/favorites_provider.dart';
import '../utils/helpers.dart';

class AuthorityCard extends ConsumerWidget {
  final Authority authority;
  final VoidCallback onTap;

  const AuthorityCard({
    required this.authority,
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
  static const Color danger = Color(0xFFD64545);
  static const Color hairline = Color(0xFFE7EAF3);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFavorite = ref.watch(favoritesProvider).contains(authority.id);

    return Material(
      color: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: () {
          // ✅ Debug : vérifier que le clic est bien capté
          print('🖱️ AuthorityCard onTap: ${authority.name}');
          onTap();
        },
        borderRadius: BorderRadius.circular(18),
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
              // AVATAR — cerclé or, badge favori si actif
              // ============================================================
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: gold, width: 1.8),
                    ),
                    child: CircleAvatar(
                      radius: 26,
                      backgroundColor: navyDeep,
                      backgroundImage: authority.imageUrl != null && authority.imageUrl!.isNotEmpty
                          ? NetworkImage(authority.imageUrl!)
                          : null,
                      child: authority.imageUrl == null || authority.imageUrl!.isEmpty
                          ? Text(
                              MonPaysHelpers.getInitials(authority.name),
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white),
                            )
                          : null,
                    ),
                  ),
                  if (isFavorite)
                    Positioned(
                      bottom: -2,
                      right: -2,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: gold,
                          shape: BoxShape.circle,
                          border: Border.all(color: pureWhite, width: 2),
                        ),
                        child: const Icon(Icons.star_rounded, size: 10, color: navyDeep),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 13),

              // ============================================================
              // NOM + TITRE
              // ============================================================
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      authority.name,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: darkText),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: ivory, borderRadius: BorderRadius.circular(20)),
                      child: Text(
                        authority.title,
                        style: const TextStyle(fontSize: 10.5, color: navy, fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),

              // ============================================================
              // ACTIONS — favori, partage, chevron
              // ============================================================
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  ref.read(favoritesProvider.notifier).toggleFavorite(authority.id);
                },
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: isFavorite ? danger.withOpacity(0.10) : ivory,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: isFavorite ? danger : mutedText,
                    size: 17,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  // TODO: Implémenter le partage
                },
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(color: ivory, shape: BoxShape.circle),
                  child: const Icon(Icons.share_rounded, size: 16, color: mutedText),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded, size: 20, color: mutedText),
            ],
          ),
        ),
      ),
    );
  }
}
