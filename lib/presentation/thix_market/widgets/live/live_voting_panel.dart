// lib/presentation/thix_market/widgets/live/live_voting_panel.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thix_id/presentation/thix_market/models/live_shopping_models.dart';
import 'package:thix_id/presentation/thix_market/providers/live_shopping_providers.dart';
import 'package:thix_id/services/live_shopping_service.dart';

class LiveVotingPanel extends ConsumerWidget {
  final String sessionId;
  const LiveVotingPanel({super.key, required this.sessionId});

  static const _navy = Color(0xFF1B2A4A);
  static const _gold = Color(0xFFE3B23C);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final candidates = ref.watch(liveVoteCandidatesProvider(sessionId));
    final service = LiveShoppingService();

    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _navy,
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Row(
            children: [
              Icon(Icons.how_to_vote_rounded, color: _gold, size: 22),
              SizedBox(width: 10),
              Text('Quel produit voir ensuite ?',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 4),
          const Text('Le produit le plus voté sera mis en vedette',
              style: TextStyle(color: Colors.white54, fontSize: 11)),
          const SizedBox(height: 14),
          candidates.when(
            loading: () => const Center(
                child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(color: _gold))),
            error: (_, __) => const Text('Erreur',
                style: TextStyle(color: Colors.white70)),
            data: (list) {
              if (list.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(
                      child: Text('Aucun produit proposé au vote.',
                          style: TextStyle(color: Colors.white54))),
                );
              }
              return ListView.separated(
                shrinkWrap: true,
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (ctx, i) {
                  final c = list[i];
                  return _VoteRow(
                    candidate: c,
                    onTap: () async {
                      HapticFeedback.selectionClick();
                      await service.toggleVote(sessionId, c.productId);
                      ref.invalidate(liveVoteCandidatesProvider(sessionId));
                    },
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _VoteRow extends StatelessWidget {
  final LiveVoteCandidate candidate;
  final VoidCallback onTap;
  const _VoteRow({required this.candidate, required this.onTap});

  static const _navy = Color(0xFF1B2A4A);
  static const _gold = Color(0xFFE3B23C);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: candidate.viewerVoted
              ? _gold.withOpacity(0.15)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: candidate.viewerVoted ? _gold : Colors.white24,
            width: candidate.viewerVoted ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.shopping_bag_rounded,
                  color: Colors.white38, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Produit ${candidate.productId.substring(0, candidate.productId.length.clamp(0, 8))}...',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: candidate.viewerVoted
                    ? _gold
                    : Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    candidate.viewerVoted
                        ? Icons.check_rounded
                        : Icons.arrow_upward_rounded,
                    size: 13,
                    color: candidate.viewerVoted ? _navy : Colors.white70,
                  ),
                  const SizedBox(width: 4),
                  Text('${candidate.voteCount}',
                      style: TextStyle(
                          color: candidate.viewerVoted ? _navy : Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w900)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
