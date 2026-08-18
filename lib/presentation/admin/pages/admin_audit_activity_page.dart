import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thix_id/supabase/supabase_config.dart';
import 'package:thix_id/theme.dart';

class AdminAuditActivityPage extends StatefulWidget {
  const AdminAuditActivityPage({super.key});

  @override
  State<AdminAuditActivityPage> createState() => _AdminAuditActivityPageState();
}

class _AdminAuditActivityPageState extends State<AdminAuditActivityPage> {
  final _search = TextEditingController();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _rows = const [];

  RealtimeChannel? _channel;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _search.addListener(_onSearchChanged);
    _load();
    _subscribeRealtime();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 160), () {
      if (mounted) setState(() {});
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await SupabaseConfig.client
          .from('thix_admin_audit_logs')
          .select('id,actor_user_id,actor_role,action,entity_type,entity_id,metadata,created_at')
          .order('created_at', ascending: false)
          .limit(250);
      if (!mounted) return;
      if (res is List) setState(() => _rows = res.cast<Map<String, dynamic>>());
    } catch (e) {
      debugPrint('AdminAuditActivityPage: fetch failed err=$e');
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _subscribeRealtime() {
    try {
      _channel = SupabaseConfig.client.channel('admin:audit');
      
      // ✅ Correction : utiliser l'API simple avec dynamic
      (_channel as dynamic)
          .on(
            'postgres_changes',
            {
              'event': '*',  // '*' pour tous les événements (INSERT, UPDATE, DELETE)
              'schema': 'public',
              'table': 'thix_admin_audit_logs',
            },
            (_) => unawaited(_load()),
          )
          .subscribe((status, [error]) {
            debugPrint('AdminAuditActivityPage: realtime status=$status, error=$error');
          });
    } catch (e) {
      debugPrint('AdminAuditActivityPage: realtime subscribe failed: $e');
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.removeListener(_onSearchChanged);
    _search.dispose();
    try {
      if (_channel != null) SupabaseConfig.client.removeChannel(_channel!);
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _search.text.trim().toLowerCase();
    final filtered = q.isEmpty
        ? _rows
        : _rows.where((r) {
            final a = (r['action'] ?? '').toString().toLowerCase();
            final e = (r['entity_type'] ?? '').toString().toLowerCase();
            final id = (r['entity_id'] ?? '').toString().toLowerCase();
            final actor = (r['actor_user_id'] ?? '').toString().toLowerCase();
            return a.contains(q) || e.contains(q) || id.contains(q) || actor.contains(q);
          }).toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Audit & Activity', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: AdminCyberColors.text)),
                  const SizedBox(height: 4),
                  Text('Source: thix_admin_audit_logs • ${filtered.length} entrée(s)', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AdminCyberColors.textDim)),
                ],
              ),
            ),
            SizedBox(
              width: 340,
              child: TextField(
                controller: _search,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AdminCyberColors.text),
                decoration: InputDecoration(
                  hintText: 'Search action, entity, actor…',
                  hintStyle: Theme.of(context).textTheme.bodySmall?.copyWith(color: AdminCyberColors.textDim),
                  prefixIcon: const Icon(Icons.search_rounded, color: AdminCyberColors.neonCyan),
                  filled: true,
                  fillColor: AdminCyberColors.panel.withValues(alpha: 0.72),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: AdminCyberColors.stroke.withValues(alpha: 0.9))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AdminCyberColors.electricBlue, width: 1.2)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AdminCyberColors.stroke.withValues(alpha: 0.9)),
                foregroundColor: AdminCyberColors.text,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded, color: AdminCyberColors.neonCyan),
              label: const Text('Fetch Data'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: Colors.white))
              : (_error != null)
                  ? Center(child: Text(_error!, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AdminCyberColors.textDim)))
                  : (filtered.isEmpty)
                      ? Center(child: Text('Aucune activité.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AdminCyberColors.textDim)))
                      : ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, i) => _AuditTile(row: filtered[i]),
                        ),
        ),
      ],
    );
  }
}

class _AuditTile extends StatelessWidget {
  final Map<String, dynamic> row;
  const _AuditTile({required this.row});

  @override
  Widget build(BuildContext context) {
    final action = (row['action'] ?? '—').toString();
    final entityType = (row['entity_type'] ?? '—').toString();
    final entityId = (row['entity_id'] ?? '').toString();
    final actor = (row['actor_user_id'] ?? '—').toString();
    final role = (row['actor_role'] ?? '').toString();
    final createdAt = (row['created_at'] ?? '').toString();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        color: AdminCyberColors.panel.withValues(alpha: 0.78),
        border: Border.all(color: AdminCyberColors.stroke.withValues(alpha: 0.9)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), gradient: AdminCyberGradients.glowBlue()),
            child: const Icon(Icons.manage_history_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$action • $entityType', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AdminCyberColors.text)),
                const SizedBox(height: 4),
                Text(
                  'entity=${entityId.isEmpty ? '—' : entityId} • actor=${_ellipsis(actor, 18)}${role.isEmpty ? '' : ' • role=${role.toUpperCase()}'} • $createdAt',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AdminCyberColors.textDim),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _ellipsis(String v, int n) => (v.length <= n) ? v : '${v.substring(0, n)}…';
}
