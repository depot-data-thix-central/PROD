// lib/presentation/thix_money/thix_money_page.dart
import 'package:flutter/material.dart';
import 'pages/dashboard_page.dart';
import 'pages/history_page.dart';
import 'pages/savings_page.dart';
import 'pages/tontines_page.dart';
import 'pages/profile_page.dart';

class ThixMoneyPage extends StatefulWidget {
  const ThixMoneyPage({super.key});
  @override
  State<ThixMoneyPage> createState() => _ThixMoneyPageState();
}

class _ThixMoneyPageState extends State<ThixMoneyPage> {
  int _index = 0;
  final _pages = const [DashboardPage(), HistoryPage(), SavingsPage(), TontinesPage(), ProfilePage()];
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_index],
      bottomNavigationBar: NavigationBar(selectedIndex: _index, onDestinationSelected: (i) => setState(() => _index = i), destinations: const [
        NavigationDestination(icon: Icon(Icons.home), label: 'Accueil'),
        NavigationDestination(icon: Icon(Icons.history), label: 'Historique'),
        NavigationDestination(icon: Icon(Icons.savings), label: 'Épargne'),
        NavigationDestination(icon: Icon(Icons.groups), label: 'Tontines'),
        NavigationDestination(icon: Icon(Icons.person), label: 'Profil'),
      ]),
    );
  }
}
