// lib/presentation/admin/pages/admin_events_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'admin_events_dashboard.dart';

class AdminEventsPage extends ConsumerWidget {
  final String role;
  
  const AdminEventsPage({super.key, required this.role});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const AdminEventsDashboard();
  }
}
