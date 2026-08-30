// lib/presentation/thix_market/widgets/products/wishlist_button.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ============================================================================
// CONSTANTES
// ============================================================================
const Duration _kRequestTimeout = Duration(seconds: 15);
const Duration _kRetryDelay = Duration(milliseconds: 400);
const int _kMaxRetries = 1;

// ============================================================================
// PROVIDER (avec écoute de session + autoDispose)
// ============================================================================

class WishlistNotifier extends AsyncNotifier<Set<String>> {
  bool _isToggling = false;
  StreamSubscription? _authSub;

  bool get isToggling => _isToggling;

  @override
  Future<Set<String>> build() async {
    debugPrint('[Wishlist] ❤️ Building wishlist state');

    // Écoute les changements d'auth (login/logout) pour recharger
    _authSub?.cancel();
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      debugPrint('[Wishlist] 🔐 Auth state changed: ${data.event} — invalidating');
      ref.invalidateSelf();
    });
    ref.onDispose(() => _authSub?.cancel());

    return _load();
  }

  Future<Set<String>> _load() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) {
      debugPrint('[Wishlist] ⚠️ Not authenticated — empty set');
      return <String>{};
    }

    try {
      final res = await Supabase.instance.client
          .from('wishlist')
          .select('product_id')
          .eq('user_id', uid)
          .timeout(_kRequestTimeout);

      final ids = (res as List)
          .map((e) => e['product_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();

      debugPrint('[Wishlist] ✓ Loaded ${ids.length} favorites');
      return ids;
    } catch (e) {
      debugPrint('[Wishlist] ❌ Load error: $e');
      rethrow;
    }
  }

  /// Refresh manuel (pull-to-refresh sur la page wishlist).
  Future<void> refresh() async {
    debugPrint('[Wishlist] 🔄 Manual refresh');
    ref.invalidateSelf();
    await future;
  }

  Future<void> toggle(String id, {BuildContext? context}) async {
    // Validation ID
    if (id.isEmpty) {
      debugPrint('[Wishlist] ⚠️ Toggle with empty ID — ignored');
      return;
    }

    // Garde anti-double-tap
    if (_isToggling) {
      debugPrint('[Wishlist] ⚠️ Toggle in progress — ignored');
      return;
    }

    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) {
      debugPrint('[Wishlist] ⚠️ Not authenticated — redirect to login');
      if (context != null && context.mounted) {
        context.go('/login');
      }
      return;
    }

    _isToggling = true;
    final cur = state.valueOrNull ?? <String>{};
    final wasFav = cur.contains(id);

    // Optimistic UI
    final optimistic = Set<String>.from(cur);
    if (wasFav) {
      optimistic.remove(id);
    } else {
      optimistic.add(id);
    }
    state = AsyncData(optimistic);

    try {
      if (wasFav) {
        await Supabase.instance.client
            .from('wishlist')
            .delete()
            .eq('user_id', uid)
            .eq('product_id', id)
            .timeout(_kRequestTimeout);
        debugPrint('[Wishlist] 💔 Removed $id');
      } else {
        await Supabase.instance.client
            .from('wishlist')
            .insert({'user_id': uid, 'product_id': id})
            .timeout(_kRequestTimeout);
        debugPrint('[Wishlist] ❤️ Added $id');
      }
    } catch (e) {
      debugPrint('[Wishlist] ❌ Toggle error: $e — rollback');

      // Rollback
      final rollback = Set<String>.from(cur);
      state = AsyncData(rollback);

      // Feedback visuel d'erreur
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(wasFav
                ? 'Impossible de retirer des favoris'
                : 'Impossible d\'ajouter aux favoris'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      _isToggling = false;
    }
  }
}

final wishlistIdsProvider =
    AsyncNotifierProvider.autoDispose<WishlistNotifier, Set<String>>(
  WishlistNotifier.new,
);

// ============================================================================
// BOUTON WISHLIST
// ============================================================================

class WishlistButton extends ConsumerStatefulWidget {
  final String productId;
  final double size;
  final Color? activeColor;
  final Color? inactiveColor;

  const WishlistButton({
    super.key,
    required this.productId,
    this.size = 24,
    this.activeColor,
    this.inactiveColor,
  });

  @override
  ConsumerState<WishlistButton> createState() => _WishlistButtonState();
}

class _WishlistButtonState extends ConsumerState<WishlistButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    // Animation "pop" : 1.0 → 1.3 → 1.0 (elastic)
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.3), weight: 0.4),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0), weight: 0.6),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final favAsync = ref.watch(wishlistIdsProvider);
    final favIds = favAsync.valueOrNull ?? <String>{};
    final isFav = favIds.contains(widget.productId);
    final isToggling = ref.watch(wishlistIdsProvider.notifier).isToggling;

    final activeColor = widget.activeColor ?? Colors.red;
    final inactiveColor = widget.inactiveColor ?? Colors.grey;

    return Semantics(
      button: true,
      label: isFav ? 'Retirer des favoris' : 'Ajouter aux favoris',
      selected: isFav,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () async {
          HapticFeedback.selectionClick();
          _ctrl.forward(from: 0);
          await ref
              .read(wishlistIdsProvider.notifier)
              .toggle(widget.productId, context: context);
        },
        child: ScaleTransition(
          scale: _scaleAnim,
          child: favAsync.isLoading
              ? SizedBox(
                  width: widget.size,
                  height: widget.size,
                  child: const CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  isFav ? Icons.favorite : Icons.favorite_border,
                  size: widget.size,
                  color: isFav ? activeColor : inactiveColor,
                ),
        ),
      ),
    );
  }
}
