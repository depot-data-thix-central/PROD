// lib/presentation/education/widgets/common/formation_card.dart
import 'package:flutter/material.dart';
import 'package:thix_id/presentation/education/models/formation.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart'; // ✅ Import du design system

class FormationCard extends StatelessWidget {
  final Formation formation;
  final VoidCallback? onTap;
  final double? progress;

  const FormationCard({
    super.key,
    required this.formation,
    this.onTap,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    // Sécurisation de l'URL de l'image
    final bool hasValidImage = formation.imageUrl != null && formation.imageUrl!.trim().isNotEmpty;
    final String displayImageUrl = hasValidImage ? formation.imageUrl! : 'https://via.placeholder.com/300x120';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: ThixPolicy.card,
          borderRadius: BorderRadius.circular(ThixPolicy.rMd),
          border: Border.all(color: ThixPolicy.border), 
          boxShadow: ThixPolicy.shadowSoft(), 
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── IMAGE DE COUVERTURE ───
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(ThixPolicy.rMd - 1)),
              child: Image.network(
                displayImageUrl,
                height: 120,
                width: double.infinity,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    height: 120,
                    color: ThixPolicy.surface,
                    child: const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2, color: ThixPolicy.primary),
                      ),
                    ),
                  );
                },
                errorBuilder: (_, __, ___) => Container(
                  height: 120,
                  color: ThixPolicy.surface,
                  child: const Center(
                    child: Icon(Icons.image_not_supported_rounded, color: ThixPolicy.textMuted, size: 32),
                  ),
                ),
              ),
            ),
            
            // ─── CONTENU DE LA CARTE ───
            Padding(
              padding: const EdgeInsets.all(ThixPolicy.s14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Titre
                  Text(
                    formation.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: ThixPolicy.textMain,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: ThixPolicy.s6),
                  
                  // 👇 Affiche uniquement l'Académie / Nom du formateur réel 👇
                  if (formation.instructorName != null && formation.instructorName!.trim().isNotEmpty) ...[
                    Text(
                      formation.instructorName!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: ThixPolicy.primaryDeep,
                      ),
                    ),
                    const SizedBox(height: ThixPolicy.s4),
                  ],

                  // Catégorie
                  Text(
                    formation.category?.name ?? 'Non catégorisé',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11, 
                      color: ThixPolicy.textSecondary, 
                      fontWeight: FontWeight.w600
                    ),
                  ),
                  
                  const SizedBox(height: ThixPolicy.s12),
                  
                  // Niveau & Prix
                  Row(
                    children: [
                      const Icon(Icons.school_rounded, size: 16, color: ThixPolicy.textSecondary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          formation.level == 'beginner' ? 'Débutant' :
                          formation.level == 'intermediate' ? 'Intermédiaire' : 'Avancé',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12, 
                            color: ThixPolicy.textSecondary, 
                            fontWeight: FontWeight.w600
                          ),
                        ),
                      ),
                      
                      // Tarif
                      if (formation.price > 0)
                        Text(
                          '${formation.price.toInt()} ${formation.currency ?? 'FC'}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: ThixPolicy.primary,
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: ThixPolicy.success.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(ThixPolicy.rSm),
                          ),
                          child: const Text(
                            'Gratuit',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: ThixPolicy.success,
                            ),
                          ),
                        ),
                    ],
                  ),
                  
                  // ─── BARRE DE PROGRESSION ───
                  if (progress != null) ...[
                    const SizedBox(height: ThixPolicy.s14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Progression',
                          style: TextStyle(
                            fontSize: 11.5, 
                            color: ThixPolicy.textSecondary, 
                            fontWeight: FontWeight.w700
                          ),
                        ),
                        Text(
                          '${(progress! * 100).toInt()}%',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w900,
                            // Devient vert si la formation est terminée
                            color: progress! >= 1.0 ? ThixPolicy.success : ThixPolicy.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: ThixPolicy.s6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(ThixPolicy.rFull),
                      child: LinearProgressIndicator(
                        value: progress!.clamp(0.0, 1.0),
                        backgroundColor: ThixPolicy.border,
                        color: progress! >= 1.0 ? ThixPolicy.success : ThixPolicy.primary,
                        minHeight: 6,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
