// lib/presentation/thix_market/widgets/live/live_host_control_panel.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/presentation/thix_market/models/live_shopping_models.dart';
import 'package:thix_id/presentation/thix_market/providers/live_shopping_providers.dart';
import 'package:thix_id/services/live_shopping_service.dart';

class LiveHostControlPanel extends ConsumerStatefulWidget {
  final String sessionId;
  final List<String> availableProductIds;

  const LiveHostControlPanel({
    super.key,
    required this.sessionId,
    required this.availableProductIds,
  });

  @override
  ConsumerState<LiveHostControlPanel> createState() =>
      _LiveHostControlPanelState();
}

class _LiveHostControlPanelState extends ConsumerState<LiveHostControlPanel> {
  final _service = LiveShoppingService();

  static const _navy = Color(0xFF1B2A4A);
  static const _gold = Color(0xFFC9962C);

  @override
  Widget build(BuildContext context) {
    final pinnedAsync = ref.watch(livePinnedProductsProvider(widget.sessionId));
    final pinned = pinnedAsync.valueOrNull ?? const [];

    // Produits disponibles = catalogue - déjà pinned
    final pinnedIds = pinned.map((p) => p.productId).toSet();
    final available = widget.availableProductIds
        .where((id) => !pinnedIds.contains(id))
        .toList();

    return Container(
      decoration: const BoxDecoration(
        color: _navy,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(16),
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: _gold,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.shopping_bag_rounded,
                    size: 15, color: _navy),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Produits du live',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900)),
              ),
              Text('${pinned.length} actifs',
                  style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 16),

          // ── Section "Actifs" (réordonnables) ──
          if (pinned.isNotEmpty) ...[
            const Text('ACTUELS (glissez pour réordonner)',
                style: TextStyle(
                    color: Colors.white60,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5)),
            const SizedBox(height: 8),
            SizedBox(
              height: 120,
              child: ReorderableListView.builder(
                scrollDirection: Axis.horizontal,
                onReorder: (old, nw) async {
                  HapticFeedback.selectionClick();
                  final reordered = List<LivePinnedProduct>.from(pinned);
                  final item = reordered.removeAt(old);
                  reordered.insert(nw > old ? nw - 1 : nw, item);
                  await _service.reorderPinned(
                    widget.sessionId,
                    reordered.map((p) => p.id).toList(),
                  );
                },
                itemCount: pinned.length,
                itemBuilder: (ctx, i) {
                  final p = pinned[i];
                  return _PinnedTile(
                    key: ValueKey(p.id),
                    pinned: p,
                    onSetFeatured: () async {
                      HapticFeedback.selectionClick();
                      await _service.setFeatured(widget.sessionId, p.id);
                    },
                    onRemove: () async {
                      HapticFeedback.mediumImpact();
                      await _service.unpinProduct(p.id);
                    },
                    onVoteCandidate: () async {
                      await _service.addVoteCandidate(
                          widget.sessionId, p.productId);
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Proposé au vote ✓'),
                          backgroundColor: _gold,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── Section "Catalogue disponible" ──
          const Text('CATALOGUE DISPONIBLE',
              style: TextStyle(
                  color: Colors.white60,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5)),
          const SizedBox(height: 8),
          if (available.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                  child: Text('Tous les produits sont épinglés',
                      style: TextStyle(color: Colors.white54, fontSize: 12))),
            )
          else
            SizedBox(
              height: 110,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: available.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (ctx, i) {
                  final pid = available[i];
                  return _AvailableTile(
                    productId: pid,
                    onPin: () async {
                      HapticFeedback.selectionClick();
                      await _service.pinProduct(widget.sessionId, pid);
                    },
                  );
                },
              ),
            ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }
}

class _PinnedTile extends StatelessWidget {
  final LivePinnedProduct pinned;
  final VoidCallback onSetFeatured;
  final VoidCallback onRemove;
  final VoidCallback onVoteCandidate;

  const _PinnedTile({
    super.key,
    required this.pinned,
    required this.onSetFeatured,
    required this.onRemove,
    required this.onVoteCandidate,
  });

  static const _navy = Color(0xFF1B2A4A);
  static const _gold = Color(0xFFC9962C);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 130,
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: pinned.isFeatured ? _gold : Colors.white24,
          width: pinned.isFeatured ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          // Image
          Container(
            height: 60,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: const Center(
              child: Icon(Icons.shopping_bag_rounded,
                  color: Colors.white38, size: 24),
            ),
          ),
          // Infos + actions
          Padding(
            padding: const EdgeInsets.all(6),
            child: Column(
              children: [
                Text(
                  pinned.productId.substring(
                      0, pinned.productId.length.clamp(0, 8)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _miniBtn(
                      icon: pinned.isFeatured
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      color: _gold,
                      onTap: onSetFeatured,
                    ),
                    const SizedBox(width: 4),
                    _miniBtn(
                      icon: Icons.how_to_vote_rounded,
                      color: const Color(0xFF7C3AED),
                      onTap: onVoteCandidate,
                    ),
                    const SizedBox(width: 4),
                    _miniBtn(
                      icon: Icons.close_rounded,
                      color: const Color(0xFFE53935),
                      onTap: onRemove,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AvailableTile extends StatelessWidget {
  final String productId;
  final VoidCallback onPin;

  const _AvailableTile({required this.productId, required this.onPin});

  static const _gold = Color(0xFFC9962C);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPin,
      child: Container(
        width: 100,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 50,
              width: 70,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.shopping_bag_rounded,
                  color: Colors.white38, size: 20),
            ),
            const SizedBox(height: 6),
            const Icon(Icons.add_circle_rounded, color: _gold, size: 22),
            const Text('Épingler',
                style: TextStyle(
                    color: Colors.white70,
                    fontSize: 9,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

Widget _miniBtn({
  required IconData icon,
  required Color color,
  required VoidCallback onTap,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(icon, color: color, size: 12),
    ),
  );
}
