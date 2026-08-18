// lib/presentation/education/pages/recommendations_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/presentation/education/providers/recommendation_provider.dart';
import 'package:thix_id/presentation/education/models/recommendation.dart';
import 'package:thix_id/presentation/education/widgets/common/education_loading_shimmer.dart';

class RecommendationsPage extends StatefulWidget {
  const RecommendationsPage({super.key});

  @override
  State<RecommendationsPage> createState() => _RecommendationsPageState();
}

class _RecommendationsPageState extends State<RecommendationsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRecommendations();
    });
  }

  Future<void> _loadRecommendations() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    final provider = context.read<RecommendationProvider>();
    await provider.loadRecommendations(userId);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RecommendationProvider>();
    final recommendations = provider.recommendations;

    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFF),
      appBar: AppBar(
        title: const Text(
          'Recommandations',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: Color(0xFF1A1A2E),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: Color(0xFF1A1A2E)),
          onPressed: () => context.pop(),
        ),
      ),
      body: provider.isLoading
          ? const EducationLoadingShimmer()
          : recommendations.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.lightbulb_outline_rounded,
                        size: 64,
                        color: Color(0xFFD1D5DB),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Aucune recommandation pour le moment',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Suivez des formations pour recevoir des suggestions',
                        style: TextStyle(
                          color: Color(0xFF7386A8),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: recommendations.length,
                  itemBuilder: (context, index) {
                    final rec = recommendations[index];

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFE7EEFC),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            rec.formation?.title ??
                                'Formation recommandée',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1A1A2E),
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (rec.reason != null)
                            Text(
                              rec.reason!,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF7386A8),
                              ),
                            ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                Icons.trending_up_rounded,
                                size: 16,
                                color: Color(0xFF2D6CDF),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Score de pertinence: ${(rec.score * 10).toInt()}%',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF2D6CDF),
                                ),
                              ),
                              const Spacer(),
                              ElevatedButton(
                                onPressed: () {
                                  if (rec.formation != null) {
                                    context.push(
                                      '/education/formation/${rec.formation!.id}',
                                    );
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      const Color(0xFF2D6CDF),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(30),
                                  ),
                                ),
                                child: const Text('Voir'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
