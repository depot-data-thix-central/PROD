import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ThixAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final List<Widget>? actions;
  final bool showBackButton;
  final bool showSearchButton;
  final bool showNotificationButton;
  final bool showCartButton;
  final VoidCallback? onSearchTap;
  final VoidCallback? onNotificationTap;
  final VoidCallback? onCartTap;
  final Color? backgroundColor;
  final bool centerTitle;

  const ThixAppBar({
    super.key,
    this.title,
    this.actions,
    this.showBackButton = false,
    this.showSearchButton = true,
    this.showNotificationButton = true,
    this.showCartButton = true,
    this.onSearchTap,
    this.onNotificationTap,
    this.onCartTap,
    this.backgroundColor,
    this.centerTitle = false,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: title != null
          ? Text(
              title!,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFFE5592F),
              ),
            )
          : Image.asset(
              'assets/images/thix_logo.png',
              height: 40,
              errorBuilder: (_, __, ___) => const Text(
                'THIX',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFE5592F),
                ),
              ),
            ),
      backgroundColor: backgroundColor ?? Colors.white,
      elevation: 0,
      centerTitle: centerTitle,
      leading: showBackButton
          ? IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black),
              onPressed: () => Navigator.pop(context),
            )
          : null,
      actions: [
        if (showSearchButton)
          IconButton(
            icon: const Icon(Icons.search, color: Colors.black),
            onPressed: onSearchTap ?? () => Navigator.pushNamed(context, '/search'),
          ),
        if (showNotificationButton)
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined, color: Colors.black),
                onPressed: onNotificationTap ?? () => Navigator.pushNamed(context, '/notifications'),
              ),
              FutureBuilder<int>(
                future: _getUnreadNotificationsCount(),
                builder: (context, snapshot) {
                  final count = snapshot.data ?? 0;
                  if (count == 0) return const SizedBox();
                  return Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        count > 9 ? '9+' : '$count',
                        style: const TextStyle(color: Colors.white, fontSize: 10),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        if (showCartButton)
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart_outlined, color: Colors.black),
                onPressed: onCartTap ?? () => Navigator.pushNamed(context, '/cart'),
              ),
              FutureBuilder<int>(
                future: _getCartItemsCount(),
                builder: (context, snapshot) {
                  final count = snapshot.data ?? 0;
                  if (count == 0) return const SizedBox();
                  return Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Color(0xFFE5592F),
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        count > 9 ? '9+' : '$count',
                        style: const TextStyle(color: Colors.white, fontSize: 10),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        if (actions != null) ...actions!,
      ],
    );
  }

  Future<int> _getUnreadNotificationsCount() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return 0;
    try {
      final query = Supabase.instance.client
          .from('notifications')
          .select('id')
          .eq('user_id', userId)
          .eq('is_read', false);
      final countResult = await query.count();
      return countResult.count ?? 0;
    } catch (e) {
      return 0;
    }
  }

  Future<int> _getCartItemsCount() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return 0;
    try {
      final query = Supabase.instance.client
          .from('cart')
          .select('id')
          .eq('user_id', userId);
      final countResult = await query.count();
      return countResult.count ?? 0;
    } catch (e) {
      return 0;
    }
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
