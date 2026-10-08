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

  void _subscribeRoleRealtime() {}

  @override
  void dispose() {
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant AdminPage oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  Future<void> _loadRole() async {}

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox();
    }

    if (_role == null) {
      return const SizedBox();
    }

    return AdminShell(
      key: _contentKey,
      module: widget.module,
      role: _role,
      child: _moduleChild(widget.module),
    );
  }

  Widget _moduleChild(AdminModule module) {
    switch (module) {
      case AdminModule.overview:
        return const AdminOverviewPage();
      default:
        return const SizedBox();
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
  String get slug => '';
  static AdminModule fromSlug(String? slug) => AdminModule.overview;
  String get label => '';
  IconData get icon => Icons.dashboard;
}
