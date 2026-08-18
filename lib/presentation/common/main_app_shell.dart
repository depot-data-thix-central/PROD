// lib/presentation/common/main_app_shell.dart
//
// Shell principal de l'application.
// Utilise StatefulShellRoute pour conserver l'état de chaque branche
// lorsque l'utilisateur bascule entre les sections principales.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MainAppShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const MainAppShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
    );
  }
}
