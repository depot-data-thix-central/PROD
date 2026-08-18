// lib/presentation/admin/pages/admin_news_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../providers/news_provider.dart';
import '../../../services/news_service.dart';
import 'admin_news_dashboard.dart';  // ← Chemin corrigé (même dossier)

class AdminNewsPage extends StatelessWidget {
  final String role;
  
  const AdminNewsPage({super.key, required this.role});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => NewsProvider(NewsService(Supabase.instance.client)),
      child: const AdminNewsDashboard(),
    );
  }
}
