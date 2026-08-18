// lib/presentation/thix_money/thix_money_router.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'thix_money_page.dart';
import 'pages/dashboard_page.dart';
import 'pages/send_page.dart';
import 'pages/recharge_page.dart';
import 'pages/retrait_page.dart';
import 'pages/scanner_page.dart';
import 'pages/history_page.dart';
import 'pages/savings_page.dart';
import 'pages/investments_page.dart';
import 'pages/loans_page.dart';
import 'pages/tontines_page.dart';
import 'pages/profile_page.dart';

class ThixMoneyRouter {
  static const base = '/thix-money';

  // Guard: vérifie que user est connecté ET que thix_id existe dans profiles
  static Future<String?> _guardThixId(BuildContext ctx, GoRouterState state) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return '/login';
    
    try {
      final res = await Supabase.instance.client.from('profiles').select('thix_id').eq('id', user.id).single();
      final thixId = res['thix_id'] as String?;
      if (thixId == null || thixId.isEmpty || thixId == 'THIX-PENDING') {
        return '/register/personal'; // force finalisation inscription
      }
      return null; // OK
    } catch (_) {
      return '/login';
    }
  }

  static final List<RouteBase> routes = [
    ShellRoute(
      builder: (context, state, child) => ThixMoneyShell(child: child),
      routes: [
        GoRoute(
          path: base,
          redirect: _guardThixId,
          builder: (ctx, s) => const DashboardPage(),
          routes: [
            GoRoute(path: 'dashboard', builder: (_, __) => const DashboardPage()),
            GoRoute(path: 'send', redirect: _guardThixId, builder: (ctx, state) {
              final extra = state.extra as Map<String, dynamic>?;
              return SendPage(initialData: extra);
            }),
            GoRoute(path: 'recharge', redirect: _guardThixId, builder: (_, __) => const RechargePage()),
            GoRoute(path: 'retrait', redirect: _guardThixId, builder: (_, __) => const RetraitPage()),
            GoRoute(path: 'scanner', redirect: _guardThixId, builder: (_, __) => const ScannerPage()),
            GoRoute(path: 'history', redirect: _guardThixId, builder: (_, __) => const HistoryPage()),
            GoRoute(path: 'savings', redirect: _guardThixId, builder: (_, __) => const SavingsPage()),
            GoRoute(path: 'investments', redirect: _guardThixId, builder: (_, __) => const InvestmentsPage()),
            GoRoute(path: 'loans', redirect: _guardThixId, builder: (_, __) => const LoansPage()),
            GoRoute(path: 'tontines', redirect: _guardThixId, builder: (_, __) => const TontinesPage()),
            GoRoute(path: 'profile', redirect: _guardThixId, builder: (_, __) => const ProfilePage()),
          ],
        ),
      ],
    ),
  ];
}

// Shell pour bottom nav persistant web/mobile
class ThixMoneyShell extends StatelessWidget {
  final Widget child;
  const ThixMoneyShell({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    return child;
  }
}
