// lib/presentation/thix_market/widgets/products/wishlist_button.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';

const String _table = 'wishlist';

/// Ensemble des product_id favoris de l'utilisateur (1 seule requête pour toutes les cartes)
final wishlistIdsProvider =
    NotifierProvider<WishlistIdsNotifier, Set<String>>(WishlistIdsNotifier.new);

class WishlistIdsNotifier extends Notifier<Set<String>> {
  bool _loading = false;

  SupabaseClient get _db => Supabase.instance.client;
  String? get _uid => _db.auth.currentUser?.id;

  @override
  Set<String> build() {
    Future.microtask(load);
    return <String>{};
  }

  Future<void> load() async {
    if (_loading) return;
    final uid = _uid;
    if (uid == null) return;
    _loading = true;
    try {
      final res = await _db
          .from(_table)
          .select('product_id')
          .eq('user_id', uid)
          .timeout(const Duration(seconds: 10));
      final ids = <String>{};
      for (final row in List<Map<String, dynamic>>.from(res as List)) {
        final id = row['product_id']?.toString();
        if (id != null && id.isNotEmpty) ids.add(id);
      }
      state = ids;
      debugPrint('[Wishlist] ✓ ${ids.length} favoris chargés');
    } catch (e) {
      debugPrint('[Wishlist] ⚠️ load error: $e');
    } finally {
      _loading = false;
    }
  }

  /// Retourne null si OK, sinon un message d'erreur.
  Future<String?> toggle(String productId) async {
    final uid = _uid;
    if (uid == null) return 'Connectez-vous pour ajouter aux favoris';
    if (productId.isEmpty) return 'Produit invalide';

    final wasLiked = state.contains(productId);

    // Optimiste : le cœur change immédiatement
    final next = Set<String>.from(state);
    wasLiked ? next.remove(productId) : next.add(productId);
    state = next;

    try {
      if (wasLiked) {
        await _db
            .from(_table)
            .delete()
            .eq('user_id', uid)
            .eq('product_id', productId)
            .timeout(const Duration(seconds: 10));
      } else {
        await _db
            .from(_table)
            .insert({'user_id': uid, 'product_id': productId})
            .timeout(const Duration(seconds: 10));
      }
      return null;
    } catch (e) {
      final msg = e.toString();
      // Doublon : déjà en favori côté serveur, on garde l'état
      if (msg.contains('23505') || msg.toLowerCase().contains('duplicate')) {
        return null;
      }
      debugPrint('[Wishlist] ❌ toggle error: $e');
      // Retour arrière
      final back = Set<String>.from(state);
      wasLiked ? back.add(productId) : back.remove(productId);
      state = back;
      return msg.length > 120 ? msg.substring(0, 120) : msg;
    }
  }
}

class WishlistButton extends ConsumerWidget {
  final String productId;
  final double size;

  const WishlistButton({super.key, required this.productId, this.size = 20});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liked = ref.watch(wishlistIdsProvider.select((s) => s.contains(productId)));

    return Semantics(
      button: true,
      label: liked ? 'Retirer des favoris' : 'Ajouter aux favoris',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () async {
          HapticFeedback.selectionClick();
          final err = await ref.read(wishlistIdsProvider.notifier).toggle(productId);
          if (err != null && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(err),
                backgroundColor: ThixPolicy.danger,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        child: SizedBox(
          width: size + 6,
          height: size + 6,
          child: Center(
            child: Icon(
              liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              size: size,
              color: liked ? ThixPolicy.danger : ThixPolicy.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
