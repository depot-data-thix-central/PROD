// lib/presentation/admin/admin_page.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:thix_id/presentation/admin/admin_routes.dart';
import 'package:thix_id/presentation/admin/admin_shell.dart';
import 'package:thix_id/presentation/admin/pages/admin_overview_page.dart';
import 'package:thix_id/presentation/admin/pages/admin_jobs_opportunities_page.dart';
import 'package:thix_id/presentation/admin/pages/admin_news_page.dart';
import 'package:thix_id/presentation/admin/pages/admin_placeholder_page.dart';
import 'package:thix_id/presentation/admin/pages/admin_sos_emergency_page.dart';
import 'package:thix_id/presentation/admin/pages/admin_user_management_page.dart';
import 'package:thix_id/presentation/admin/pages/admin_verification_page.dart';
import 'package:thix_id/presentation/admin/pages/admin_events_page.dart';
import 'package:thix_id/presentation/admin/pages/admin_trainings_page.dart';
import 'package:thix_id/presentation/admin/pages/admin_audit_activity_page.dart';
import 'package:thix_id/presentation/admin/pages/admin_access_requests_page.dart';
import 'package:thix_id/presentation/admin/pages/admin_media_page.dart';
import 'package:thix_id/services/admin_rbac_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/supabase/supabase_config.dart';

// ============================================================
// COULEURS LOCALES
// ============================================================
class _AdminPageColors {
  static const Color primary = Color(0xFF1A237E);
  static const Color secondary = Color(0xFFD4AF37);
  static const Color accent = Color(0xFF00BCD4);
  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFF57C00);
  static const Color error = Color(0xFFC62828);
  static const Color info = Color(0xFF0288D1);
}

class AdminPage extends StatefulWidget {
  final AdminModule module;

  const AdminPage({super.key, required this.module});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final _rbac = AdminRbacService();
  String? _role;
  bool _loading = true;

  RealtimeChannel? _roleChannel;
  
  Key _contentKey = const ValueKey('admin_content');

  @override
  void initState() {
    super.initState();
    _loadRole();
    _subscribeRoleRealtime();
  }

  void _subscribeRoleRealtime() {
    final uid = SupabaseConfig.client.auth.currentUser?.id;
    if (uid == null || uid.trim().isEmpty) return;
    
    try {
      _roleChannel = SupabaseConfig.client.channel('admin:rbac:$uid');
      
      (_roleChannel as dynamic)
          .on(
            'postgres_changes',
            {
              'event': '*',
              'schema': 'public',
              'table': AdminRbacService.table,
              'filter': 'user_id=eq.$uid',
            },
            (_) => _loadRole(),
          )
          .subscribe((status, [error]) {
            debugPrint('AdminPage realtime: status=$status, error=$error');
          });
    } catch (e) {
      debugPrint('AdminPage: role realtime subscribe failed err=$e');
    }
  }

  @override
  void dispose() {
    try {
      if (_roleChannel != null) SupabaseConfig.client.removeChannel(_roleChannel!);
    } catch (_) {}
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant AdminPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.module != widget.module) {
      debugPrint('🔄 Module changé: ${oldWidget.module.slug} → ${widget.module.slug}');
      _contentKey = ValueKey('admin_${widget.module.slug}_${DateTime.now().millisecondsSinceEpoch}');
      setState(() {});
    }
  }

  Future<void> _loadRole() async {
    setState(() => _loading = true);
    try {
      final r = await _rbac.fetchMyRole();
      if (!mounted) return;
      setState(() => _role = r);
    } catch (e) {
      debugPrint('AdminPage: fetch role failed err=$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return AdminShell(
        module: widget.module,
        role: null,
        child: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(_AdminPageColors.secondary),
          ),
        ),
      );
    }

    if (_role == null) {
      return AdminShell(
        module: widget.module,
        role: null,
        child: AdminPlaceholderPage(
          title: 'Accès Restreint',
          description: 'Votre compte est authentifié mais aucun rôle administrateur n\'est assigné.\n\nDemandez à un Super Admin de vous accorder les droits dans `thix_admin_memberships`.',
          icon: Icons.lock_rounded,
        ),
      );
    }

    return AdminShell(
      key: _contentKey,
      module: widget.module, 
      role: _role, 
      child: _moduleChild(widget.module)
    );
  }

  Widget _moduleChild(AdminModule module) {
    switch (module) {
      case AdminModule.overview:
        return const AdminOverviewPage();
      case AdminModule.accessRequests:
        return const AdminAccessRequestsPage();
      case AdminModule.users:
        return const AdminUserManagementPage();
      case AdminModule.verification:
        return const AdminVerificationPage();
      case AdminModule.events:
  return AdminEventsPage(role: _role ?? '');
      case AdminModule.trainings:
        return const AdminTrainingsPage();
      case AdminModule.uid:
        return const AdminPlaceholderPage(
          title: 'Gestion THIX UID',
          description: 'Génération et cycle de vie des THIX UIDs, liaison biométrique, validation d\'identité.',
          icon: Icons.badge_rounded,
        );
      case AdminModule.jobs:
        return const AdminJobsOpportunitiesPage();
      case AdminModule.news:
        return AdminNewsPage(role: _role ?? '');
      case AdminModule.chat:
        return const AdminPlaceholderPage(
          title: 'Administration THIX Chat',
          description: 'Modération, signalements, analyse des conversations, politiques de surveillance sécurisées.',
          icon: Icons.forum_rounded,
        );
      case AdminModule.sos:
        return const AdminSosEmergencyPage();
      case AdminModule.institutions:
        return const AdminPlaceholderPage(
          title: 'Panel Universités & Institutions',
          description: 'Intégration des partenaires, workflows de validation académique, outils de certification en masse, analytiques.',
          icon: Icons.account_balance_rounded,
        );
      case AdminModule.analytics:
        return const AdminPlaceholderPage(
          title: 'Analytiques & Rapports',
          description: 'Graphiques en temps réel, croissance, analyses de fraude, engagement, exports.',
          icon: Icons.query_stats_rounded,
        );
      case AdminModule.cybersecurity:
        return const AdminPlaceholderPage(
          title: 'Centre de Cybersécurité',
          description: 'Surveillance des menaces, détection d\'anomalies, journaux d\'audit, état du chiffrement, santé des serveurs.',
          icon: Icons.shield_rounded,
        );
      case AdminModule.api:
        return const AdminPlaceholderPage(
          title: 'Centre API & Intégration',
          description: 'Clés API, intégrations externes, API gouvernementales, tableaux de bord d\'entreprise.',
          icon: Icons.api_rounded,
        );
      case AdminModule.settings:
        return const AdminPlaceholderPage(
          title: 'Paramètres Administrateur',
          description: 'Personnalisation, localisation, système de permissions, règles de notification.',
          icon: Icons.tune_rounded,
        );
      case AdminModule.audit:
        return const AdminAuditActivityPage();
      case AdminModule.media:
        return const AdminMediaPage();
    }
  }
}

enum AdminModule {
  overview,
  accessRequests,
  users,
  verification,
  events,
  trainings,
  uid,
  jobs,
  news,
  chat,
  sos,
  institutions,
  analytics,
  cybersecurity,
  api,
  settings,
  audit,
  media,
}

extension AdminModuleX on AdminModule {
  String get slug {
    switch (this) {
      case AdminModule.overview:
        return 'overview';
      case AdminModule.accessRequests:
        return 'access-requests';
      case AdminModule.users:
        return 'users';
      case AdminModule.verification:
        return 'verification';
      case AdminModule.events:
        return 'events';
      case AdminModule.trainings:
        return 'trainings';
      case AdminModule.uid:
        return 'uid';
      case AdminModule.jobs:
        return 'jobs';
      case AdminModule.news:
        return 'news';
      case AdminModule.chat:
        return 'chat';
      case AdminModule.sos:
        return 'sos';
      case AdminModule.institutions:
        return 'institutions';
      case AdminModule.analytics:
        return 'analytics';
      case AdminModule.cybersecurity:
        return 'cybersecurity';
      case AdminModule.api:
        return 'api';
      case AdminModule.settings:
        return 'settings';
      case AdminModule.audit:
        return 'audit';
      case AdminModule.media:
        return 'media';
    }
  }

  static AdminModule fromSlug(String? slug) {
    final s = (slug ?? '').trim().toLowerCase();
    for (final m in AdminModule.values) {
      if (m.slug == s) return m;
    }
    return AdminModule.overview;
  }
  
  String get label {
    switch (this) {
      case AdminModule.overview:
        return 'Vue d\'ensemble';
      case AdminModule.accessRequests:
        return 'Demandes d\'accès';
      case AdminModule.users:
        return 'Utilisateurs';
      case AdminModule.verification:
        return 'Vérifications';
      case AdminModule.events:
        return 'Événements';
      case AdminModule.trainings:
        return 'Formations';
      case AdminModule.uid:
        return 'Gestion UID';
      case AdminModule.jobs:
        return 'Offres d\'emploi';
      case AdminModule.news:
        return 'Actualités';
      case AdminModule.chat:
        return 'Chat';
      case AdminModule.sos:
        return 'SOS Urgences';
      case AdminModule.institutions:
        return 'Institutions';
      case AdminModule.analytics:
        return 'Analytiques';
      case AdminModule.cybersecurity:
        return 'Cybersécurité';
      case AdminModule.api:
        return 'API';
      case AdminModule.settings:
        return 'Paramètres';
      case AdminModule.audit:
        return 'Audit';
      case AdminModule.media:
        return 'Médias';
    }
  }
  
  IconData get icon {
    switch (this) {
      case AdminModule.overview:
        return Icons.dashboard;
      case AdminModule.accessRequests:
        return Icons.request_page;
      case AdminModule.users:
        return Icons.people;
      case AdminModule.verification:
        return Icons.verified;
      case AdminModule.events:
        return Icons.event;
      case AdminModule.trainings:
        return Icons.school;
      case AdminModule.uid:
        return Icons.badge;
      case AdminModule.jobs:
        return Icons.work;
      case AdminModule.news:
        return Icons.newspaper;
      case AdminModule.chat:
        return Icons.chat;
      case AdminModule.sos:
        return Icons.sos;
      case AdminModule.institutions:
        return Icons.account_balance;
      case AdminModule.analytics:
        return Icons.analytics;
      case AdminModule.cybersecurity:
        return Icons.security;
      case AdminModule.api:
        return Icons.api;
      case AdminModule.settings:
        return Icons.settings;
      case AdminModule.audit:
        return Icons.history;
      case AdminModule.media:
        return Icons.photo_library;
    }
  }
}
