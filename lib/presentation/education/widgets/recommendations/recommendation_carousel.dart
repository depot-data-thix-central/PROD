// lib/presentation/education/widgets/recommendations/recommendation_carousel.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:thix_id/presentation/education/providers/recommendation_provider.dart';
import 'package:thix_id/presentation/education/models/recommendation.dart';

class RecommendationCarousel extends StatelessWidget {
  const RecommendationCarousel({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RecommendationProvider>();
    final recommendations = provider.recommendations;

    if (recommendations.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Recommandé pour vous',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E)),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: recommendations.length,
            itemBuilder: (context, index) {
              final rec = recommendations[index];
              final formation = rec.formation;
              if (formation == null) return const SizedBox.shrink();
              return GestureDetector(
                onTap: () => context.push('/education/formation/${formation.id}'),
                child: Container(
                  width: 220,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0A1F44).withOpacity(0.06),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 90,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F7FF),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                          image: formation.imageUrl != null
                              ? DecorationImage(
                                  image: NetworkImage(formation.imageUrl!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              formation.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1A1A2E),
                              ),
                            ),
                            const SizedBox(height: 4),
                            if (rec.reason != null)
                              Text(
                                rec.reason!,
                                style: const TextStyle(fontSize: 11, color: Color(0xFF7386A8)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
