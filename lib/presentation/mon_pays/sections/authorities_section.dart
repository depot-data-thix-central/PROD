// lib/presentation/mon_pays/sections/authorities_section.dart
// Section affichant les 4 plus hautes autorités (Président, Sénat, AN, Première Ministre)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/authorities_provider.dart';
import '../models/authority.dart';

class AuthoritiesSection extends ConsumerWidget {
  const AuthoritiesSection({super.key});

  // Couleurs de la charte (pour éviter les erreurs)
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
    final authoritiesAsync = ref.watch(topAuthoritiesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // En‑tête de la section
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: navy.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.account_balance,
                      color: navy,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    '🏛 Autorités',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () {
                  context.push('/mon-pays/authorities');
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: navy.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Text(
                        'Voir tout',
                        style: TextStyle(
                          color: navy,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_ios,
                        color: navy,
                        size: 12,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Corps de la section
        authoritiesAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(navy),
                strokeWidth: 2,
              ),
            ),
          ),
          error: (error, stack) => Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: danger.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.error_outline,
                      color: danger,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Impossible de charger les autorités',
                    style: TextStyle(
                      color: mutedText,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () {
                      ref.invalidate(topAuthoritiesProvider);
                    },
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Réessayer'),
                    style: TextButton.styleFrom(
                      foregroundColor: navy,
                    ),
                  ),
                ],
              ),
            ),
          ),
          data: (authorities) {
            if (authorities.isEmpty) {
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
                child: const Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.people_outline,
                        size: 48,
                        color: mutedText,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Aucune autorité enregistrée',
                        style: TextStyle(
                          fontSize: 14,
                          color: mutedText,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Les autorités seront bientôt disponibles',
                        style: TextStyle(
                          fontSize: 12,
                          color: mutedText,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            // On affiche les 4 autorités en scroll horizontal
            final displayList = authorities.take(4).toList();
            return SizedBox(
              height: 150,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: displayList.length,
                itemBuilder: (context, index) {
                  final authority = displayList[index];
                  return Container(
                    width: 140,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: pureWhite,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: hairline),
                      boxShadow: [
                        BoxShadow(
                          color: navyDeep.withOpacity(0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        context.push('/mon-pays/authority/${authority.id}');
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Photo de profil ou initiales
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: gold, width: 2),
                                color: ivory,
                                image: authority.imageUrl != null && authority.imageUrl!.isNotEmpty
                                    ? DecorationImage(
                                        image: NetworkImage(authority.imageUrl!),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                              child: authority.imageUrl == null || authority.imageUrl!.isEmpty
                                  ? Center(
                                      child: Text(
                                        authority.name.isNotEmpty
                                            ? authority.name[0].toUpperCase()
                                            : '?',
                                        style: const TextStyle(
                                          color: navy,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 22,
                                        ),
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              authority.name,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: darkText,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              authority.title,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 10,
                                color: mutedText,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
        // Séparateur visuel
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Divider(height: 1),
        ),
      ],
    );
  }
}
