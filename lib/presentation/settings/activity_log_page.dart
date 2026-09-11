import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'package:thix_id/l10n/app_localizations.dart';
import 'package:thix_id/core/theme/thix_design_policy.dart';

class ActivityLogPage extends StatefulWidget {
  const ActivityLogPage({super.key});

  @override
  State<ActivityLogPage> createState() => _ActivityLogPageState();
}

class _ActivityLogPageState extends State<ActivityLogPage> {
  final _sb = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _logs = [];

  @override
  void initState() {
    super.initState();
    _fetchActivityLogs();
  }

  Future<void> _fetchActivityLogs() async {
    try {
      final uid = _sb.auth.currentUser?.id;
      if (uid == null) return;

      // Adapte le nom de la table ("activity_logs" ou "audit_logs") selon ton schéma Supabase
      final response = await _sb
          .from('activity_logs')
          .select()
          .eq('user_id', uid)
          .order('created_at', ascending: false)
          .limit(50);

      if (mounted) {
        setState(() {
          _logs = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[ActivityLog] Erreur: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  IconData _getIconForAction(String? action) {
    final a = action?.toLowerCase() ?? '';
    if (a.contains('login') || a.contains('connexion')) return Icons.login_rounded;
    if (a.contains('password') || a.contains('mot de passe')) return Icons.vpn_key_rounded;
    if (a.contains('device') || a.contains('appareil')) return Icons.devices_rounded;
    if (a.contains('sos')) return Icons.sos_rounded;
    return Icons.circle_notifications_rounded;
  }

  Color _getColorForAction(String? action) {
    final a = action?.toLowerCase() ?? '';
    if (a.contains('fail') || a.contains('erreur')) return ThixPolicy.danger;
    if (a.contains('sos')) return Colors.orange;
    if (a.contains('password')) return ThixPolicy.warning;
    return ThixPolicy.primary;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(l10n.t('settings_activity_log')),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _logs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history_rounded, size: 64, color: Theme.of(context).dividerColor),
                      const SizedBox(height: 16),
                      Text(l10n.t('security_no_events'), style: ThixPolicy.bodyStyle),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _logs.length,
                  itemBuilder: (context, index) {
                    final log = _logs[index];
                    final date = DateTime.tryParse(log['created_at'].toString()) ?? DateTime.now();
                    final action = log['action']?.toString() ?? 'Action inconnue';
                    final details = log['details']?.toString();
                    final ip = log['ip_address']?.toString();

                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Theme.of(context).dividerColor),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: CircleAvatar(
                          backgroundColor: _getColorForAction(action).withOpacity(0.15),
                          child: Icon(_getIconForAction(action), color: _getColorForAction(action)),
                        ),
                        title: Text(action, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (details != null) Text(details),
                              if (ip != null) 
                                Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Text('IP : $ip', style: const TextStyle(fontSize: 11)),
                                ),
                              const SizedBox(height: 8),
                              Text(
                                timeago.format(date, locale: 'fr'),
                                style: TextStyle(color: Theme.of(context).primaryColor, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
