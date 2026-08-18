import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:thix_id/services/admin_access_request_service.dart';
import 'package:thix_id/theme.dart';

class AdminAccessRequestsPage extends StatefulWidget {
  const AdminAccessRequestsPage({super.key});

  @override
  State<AdminAccessRequestsPage> createState() => _AdminAccessRequestsPageState();
}

class _AdminAccessRequestsPageState extends State<AdminAccessRequestsPage> {
  final _service = AdminAccessRequestService();
  String _status = 'pending';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(
          status: _status,
          onStatusChanged: (s) => setState(() => _status = s),
        ),
        const SizedBox(height: AppSpacing.md),
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: _service.streamLatest(status: _status),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Colors.white));
              }
              final rows = snap.data ?? const <Map<String, dynamic>>[];
              if (rows.isEmpty) {
                return _Empty(status: _status);
              }
              return ListView.separated(
                itemCount: rows.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) => _RequestCard(
                  row: rows[i],
                  onApprove: () async {
                    try {
                      await _service.decide(requestId: (rows[i]['id'] ?? '').toString(), newStatus: 'approved', decidedRole: (rows[i]['desired_role'] ?? 'admin').toString());
                    } catch (e) {
                      debugPrint('AdminAccessRequestsPage approve failed err=$e');
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                    }
                  },
                  onReject: () async {
                    try {
                      await _service.decide(requestId: (rows[i]['id'] ?? '').toString(), newStatus: 'rejected');
                    } catch (e) {
                      debugPrint('AdminAccessRequestsPage reject failed err=$e');
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                    }
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  final String status;
  final ValueChanged<String> onStatusChanged;

  const _Header({required this.status, required this.onStatusChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Account Access Requests',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: AdminCyberColors.text, fontWeight: FontWeight.w900),
          ),
        ),
        _StatusChip(
          label: 'Pending',
          value: 'pending',
          selected: status == 'pending',
          onTap: () => onStatusChanged('pending'),
        ),
        const SizedBox(width: 8),
        _StatusChip(
          label: 'Approved',
          value: 'approved',
          selected: status == 'approved',
          onTap: () => onStatusChanged('approved'),
        ),
        const SizedBox(width: 8),
        _StatusChip(
          label: 'Rejected',
          value: 'rejected',
          selected: status == 'rejected',
          onTap: () => onStatusChanged('rejected'),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final String value;
  final bool selected;
  final VoidCallback onTap;

  const _StatusChip({required this.label, required this.value, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final border = selected ? AdminCyberColors.neonCyan.withValues(alpha: 0.55) : AdminCyberColors.stroke.withValues(alpha: 0.8);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: selected ? AdminCyberColors.panelHi.withValues(alpha: 0.88) : AdminCyberColors.panel.withValues(alpha: 0.62),
          border: Border.all(color: border, width: 1),
        ),
        child: Text(label, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: selected ? AdminCyberColors.text : AdminCyberColors.textDim, fontWeight: FontWeight.w800)),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final String status;
  const _Empty({required this.status});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AdminCyberColors.stroke.withValues(alpha: 0.9)),
            color: AdminCyberColors.panel.withValues(alpha: 0.76),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), gradient: AdminCyberGradients.glowBlue()),
                child: const Icon(Icons.inbox_rounded, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('No requests', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AdminCyberColors.text)),
                    const SizedBox(height: 6),
                    Text('There are no "$status" admin access requests right now.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AdminCyberColors.textDim, height: 1.5)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final Map<String, dynamic> row;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _RequestCard({required this.row, required this.onApprove, required this.onReject});

  @override
  Widget build(BuildContext context) {
    final requester = (row['requester_id'] ?? '').toString();
    final desiredRole = ((row['desired_role'] ?? 'admin').toString()).toUpperCase();
    final message = (row['message'] ?? '').toString();
    final status = (row['status'] ?? '').toString();
    final createdAt = (row['created_at'] ?? '').toString();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        color: AdminCyberColors.panel.withValues(alpha: 0.78),
        border: Border.all(color: AdminCyberColors.stroke.withValues(alpha: 0.95)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), gradient: AdminCyberGradients.glowViolet()),
            child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Requester: $requester',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AdminCyberColors.text, fontWeight: FontWeight.w900),
                      ),
                    ),
                    _Pill(text: desiredRole, color: AdminCyberColors.neonCyan),
                    const SizedBox(width: 8),
                    _Pill(text: status.toUpperCase(), color: _statusColor(status)),
                  ],
                ),
                const SizedBox(height: 8),
                if (message.trim().isNotEmpty)
                  Text(message, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AdminCyberColors.textDim, height: 1.45)),
                if (message.trim().isNotEmpty) const SizedBox(height: 10),
                Text('Created: $createdAt', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AdminCyberColors.textDim.withValues(alpha: 0.9))),
                const SizedBox(height: 12),
                if (status.trim().toLowerCase() == 'pending')
                  Row(
                    children: [
                      _ActionButton(
                        label: 'Reject',
                        icon: Icons.close_rounded,
                        color: AdminCyberColors.danger,
                        onTap: onReject,
                      ),
                      const SizedBox(width: 10),
                      _ActionButton(
                        label: 'Approve',
                        icon: Icons.check_rounded,
                        color: AdminCyberColors.neonCyan,
                        onTap: onApprove,
                      ),
                    ],
                  )
                else
                  Text('Decision recorded.', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AdminCyberColors.textDim)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Color _statusColor(String raw) {
    final s = raw.trim().toLowerCase();
    if (s == 'approved') return AdminCyberColors.success;
    if (s == 'rejected') return AdminCyberColors.danger;
    return AdminCyberColors.neonViolet;
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final Color color;
  const _Pill({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withValues(alpha: 0.16),
        border: Border.all(color: color.withValues(alpha: 0.32), width: 1),
      ),
      child: Text(text, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AdminCyberColors.text, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({required this.label, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.35), width: 1),
            color: AdminCyberColors.panelHi.withValues(alpha: 0.62),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 10),
              Text(label, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AdminCyberColors.text, fontWeight: FontWeight.w900)),
            ],
          ),
        ),
      ),
    );
  }
}
