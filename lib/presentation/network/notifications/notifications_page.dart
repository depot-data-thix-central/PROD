import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/services/network_service.dart';
import 'package:thix_id/models/network_notification.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});
  @override State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  late NetworkService _networkService;
  List<NetworkNotification> _all = [];
  List<NetworkNotification> _filtered = [];
  bool _loading = true;

  @override void initState() { super.initState(); _networkService = NetworkService(Supabase.instance.client); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; });
    try { final n = await _networkService.getNotifications(); setState(() { _all = n; _filtered = n; _loading = false; }); await _networkService.markAllNotificationsAsRead(); } catch (_) { setState(() { _loading = false; }); }
  }

  String _fmt(DateTime d) { final diff = DateTime.now().difference(d); if (diff.inDays > 0) return '${diff.inDays}j'; if (diff.inHours > 0) return '${diff.inHours}h'; return '${diff.inMinutes}m'; }

  @override Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(title: const Text('Notifications')),
      body: _loading? const Center(child: CircularProgressIndicator()) : _filtered.isEmpty? const Center(child: Text('Aucune notification')) : RefreshIndicator(onRefresh: _load, child: ListView.separated(itemCount: _filtered.length, separatorBuilder: (_, __) => const Divider(height: 0), itemBuilder: (_, i) {
        final n = _filtered[i];
        IconData icon = Icons.notifications;
        if (n.type == 'like') icon = Icons.favorite;
        if (n.type == 'comment') icon = Icons.comment;
        return ListTile(leading: Icon(icon), title: Text(n.title), subtitle: Text('${n.body}\n${_fmt(n.createdAt)}'), isThreeLine: true, onTap: () { if (n.postId!= null) context.push('/network/post/${n.postId}'); });
      })),
    );
  }
}
