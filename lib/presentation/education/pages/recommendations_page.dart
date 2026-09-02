// lib/presentation/education/pages/recommendations_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';
import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/presentation/education/providers/recommendation_provider.dart';
import 'package:thix_id/presentation/education/widgets/common/education_loading_shimmer.dart';

/// Page des recommandations personnalisées
///
/// ✅ Riverpod pur (migration depuis Provider)
/// ✅ Logs structurés [Recommendations]
/// ✅ Error handling avec retry
/// ✅ Mounted checks sur toutes les opérations async
class RecommendationsPage extends ConsumerStatefulWidget {
  const RecommendationsPage({super.key});

  @override
  ConsumerState<RecommendationsPage> createState() =>
      _RecommendationsPageState();
}

class _RecommendationsPageState extends ConsumerState<RecommendationsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRecommendations();
    });
  }

  Future<void> _loadRecommendations() async {
    if (!mounted) return;

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      debugPrint('[Recommendations] ⚠️ No user logged in');
      return;
    }

    // ✅ Riverpod : ref.read au lieu de context.read
    final notifier = ref.read(recommendationProvider.notifier);
    await notifier.loadRecommendations(userId);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // ✅ Riverpod : ref.watch au lieu de context.watch
    final state = ref.watch(recommendationProvider);
    final recommendations = state.recommendations;

    return Scaffold(
      backgroundColor: ThixPolicy.inkDeep,
      appBar: AppBar(
        title: Text(
          l10n.t('recommendations_title'),
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: ThixPolicy.textMain,
          ),
        ),
        backgroundColor: ThixPolicy.card,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: ThixPolicy.textMain),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (state.isInitialized && !state.isLoading)
            IconButton(
              icon: Icon(Icons.refresh_rounded, color: ThixPolicy.textMain),
              tooltip: l10n.t('common_refresh'),
              onPressed: () {
                HapticFeedback.lightImpact();
                ref.read(recommendationProvider.notifier).refresh();
              },
            ),
        ],
      ),
      body: _buildBody(state, recommendations, l10n),
    );
  }

  Widget _buildBody(
    RecommendationsState state,
    List<dynamic> recommendations,
    AppLocalizations l10n,
  ) {
    // État loading
    if (state.isLoading && !state.isInitialized) {
      return const EducationLoadingShimmer();
    }

    // État erreur
    if (state.error != null && recommendations.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline_rounded,
                  size: 64, color: ThixPolicy.danger),
              const SizedBox(height: 16),
              Text(
                l10n.t('recommendations_error'),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: ThixPolicy.textMain,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                state.error!,
                style: TextStyle(color: ThixPolicy.textMuted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  _loadRecommendations();
                },
                icon: const Icon(Icons.refresh_rounded),
                label: Text(l10n.t('common_retry')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ThixPolicy.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // État vide
    if (recommendations.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lightbulb_outline_rounded,
                  size: 64, color: ThixPolicy.textMuted),
              const SizedBox(height: 16),
              Text(
                l10n.t('recommendations_empty_title'),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: ThixPolicy.textMain,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.t('recommendations_empty_subtitle'),
                style: TextStyle(color: ThixPolicy.textMuted),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // Liste des recommandations
    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(recommendationProvider.notifier).refresh();
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: recommendations.length,
        itemBuilder: (context, index) {
          final rec = recommendations[index];
          return _RecommendationCard(recommendation: rec);
        },
      ),
    );
  }
}

/// Carte individuelle d'une recommandation
class _RecommendationCard extends StatelessWidget {
  final dynamic recommendation;
  const _RecommendationCard({required this.recommendation});

  @override
  Widget build(BuildContext context) {
    final rec = recommendation;
    final scorePercent = ((rec.score ?? 0) * 10).toInt().clamp(0, 100);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ThixPolicy.card,
        borderRadius: BorderRadius.circular(ThixPolicy.rLg),
        border: Border.all(color: ThixPolicy.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Titre de la formation
          Text(
            rec.formation?.title ?? 'Formation recommandée',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: ThixPolicy.textMain,
            ),
          ),

          // Raison de la recommandation
          if (rec.reason != null && rec.reason!.toString().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              rec.reason!,
              style: TextStyle(
                fontSize: 13,
                color: ThixPolicy.textMuted,
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Score + bouton Voir
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: ThixPolicy.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(ThixPolicy.rSm),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.trending_up_rounded,
                      size: 14,
                      color: ThixPolicy.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$scorePercent%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: ThixPolicy.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  if (rec.formation != null && rec.formation!.id != null) {
                    context.push(
                      '/education/formation/${rec.formation!.id}',
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: ThixPolicy.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                ),
                child: const Text('Voir'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
