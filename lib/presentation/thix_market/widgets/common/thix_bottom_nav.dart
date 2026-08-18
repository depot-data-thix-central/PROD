import 'package:flutter/material.dart';

class ThixBottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const ThixBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: onTap,
      elevation: 0,
      backgroundColor: Colors.white,
      indicatorColor: const Color(0xFFE5592F).withOpacity(0.1),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home, color: Color(0xFFE5592F)),
          label: 'Accueil',
        ),
        NavigationDestination(
          icon: Icon(Icons.search_outlined),
          selectedIcon: Icon(Icons.search, color: Color(0xFFE5592F)),
          label: 'Rechercher',
        ),
        NavigationDestination(
          icon: Icon(Icons.store_outlined),
          selectedIcon: Icon(Icons.store, color: Color(0xFFE5592F)),
          label: 'Boutiques',
        ),
        NavigationDestination(
          icon: Icon(Icons.shopping_bag_outlined),
          selectedIcon: Icon(Icons.shopping_bag, color: Color(0xFFE5592F)),
          label: 'Acheter',
        ),
        NavigationDestination(
          icon: Icon(Icons.sell_outlined),
          selectedIcon: Icon(Icons.sell, color: Color(0xFFE5592F)),
          label: 'Vendre',
        ),
        NavigationDestination(
          icon: Icon(Icons.message_outlined),
          selectedIcon: Icon(Icons.message, color: Color(0xFFE5592F)),
          label: 'Messages',
        ),
        NavigationDestination(
          icon: Icon(Icons.live_tv_outlined),
          selectedIcon: Icon(Icons.live_tv, color: Color(0xFFE5592F)),
          label: 'LIVE',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person, color: Color(0xFFE5592F)),
          label: 'Activité',
        ),
        NavigationDestination(
          icon: Icon(Icons.settings_outlined),
          selectedIcon: Icon(Icons.settings, color: Color(0xFFE5592F)),
          label: 'Paramètres',
        ),
      ],
    );
  }
}
