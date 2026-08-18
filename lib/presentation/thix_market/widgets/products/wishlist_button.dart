import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final wishlistIdsProvider =
    StateNotifierProvider<WishlistNotifier, Set<String>>((ref) {
  return WishlistNotifier();
});

class WishlistNotifier extends StateNotifier<Set<String>> {
  WishlistNotifier() : super(<String>{}) {
    _load();
  }

  Future<void> _load() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final res = await Supabase.instance.client
         .from('wishlist')
         .select('product_id')
         .eq('user_id', uid);
      final ids = (res as List).map((e) => e['product_id'].toString()).toSet();
      state = ids;
    } catch (_) {}
  }

  Future<void> toggle(String id) async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;

    final wasFav = state.contains(id);
    final newSet = Set<String>.from(state);
    if (wasFav) {
      newSet.remove(id);
    } else {
      newSet.add(id);
    }
    state = newSet;

    try {
      if (wasFav) {
        await Supabase.instance.client
           .from('wishlist')
           .delete()
           .match({'user_id': uid, 'product_id': id});
      } else {
        await Supabase.instance.client
           .from('wishlist')
           .insert({'user_id': uid, 'product_id': id});
      }
    } catch (_) {
      final rollback = Set<String>.from(state);
      if (wasFav) {
        rollback.add(id);
      } else {
        rollback.remove(id);
      }
      state = rollback;
    }
  }
}

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
  late Animation<double> _anim;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _anim = Tween<double>(begin: 1.0, end: 0.8).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final favIds = ref.watch(wishlistIdsProvider);
    final isFav = favIds.contains(widget.productId);

    return GestureDetector(
      onTap: () async {
        final uid = Supabase.instance.client.auth.currentUser?.id;
        if (uid == null) {
          if (mounted) context.go('/login');
          return;
        }
        _ctrl.forward().then((_) => _ctrl.reverse());
        setState(() => _loading = true);
        await ref.read(wishlistIdsProvider.notifier).toggle(widget.productId);
        if (mounted) setState(() => _loading = false);
      },
      child: ScaleTransition(
        scale: _anim,
        child: _loading
           ? SizedBox(
                width: widget.size,
                height: widget.size,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: isFav
                     ? (widget.activeColor?? Colors.red)
                      : Colors.grey,
                ),
              )
            : Icon(
                isFav? Icons.favorite : Icons.favorite_border,
                size: widget.size,
                color: isFav
                   ? (widget.activeColor?? Colors.red)
                    : (widget.inactiveColor?? Colors.grey),
              ),
      ),
    );
  }
}
