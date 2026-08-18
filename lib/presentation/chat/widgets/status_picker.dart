import 'package:flutter/material.dart';
import '../../../models/chat/user_status.dart';

// Charte White Enterprise
class _C {
  static const bg = Colors.white;
  static const searchBg = Color(0xFFF8FAFC);
  static const border = Color(0xFFE2E8F0);
  static const primary = Color(0xFF1D4ED8);
  static const textMain = Color(0xFF0F172A);
  static const textMuted = Color(0xFF64748B);
}

class StatusPicker extends StatelessWidget {
  final Function(String status, String? customStatus) onStatusSelected;
  final String currentStatus;

  const StatusPicker({
    super.key,
    required this.onStatusSelected,
    required this.currentStatus,
  });

  @override
  Widget build(BuildContext context) {
    final statuses = [
      UserStatus.online,
      UserStatus.busy,
      UserStatus.away,
      UserStatus.doNotDisturb,
      UserStatus.offline,
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: const BoxDecoration(
        color: _C.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: _C.border, borderRadius: BorderRadius.circular(3)))),
          const SizedBox(height: 20),
          const Text('Choisissez votre statut', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _C.textMain)),
          const SizedBox(height: 12),
          ...statuses.map((status) {
            final isSelected = status == currentStatus;
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: isSelected ? _C.searchBg : _C.bg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isSelected ? _C.primary.withOpacity(0.2) : _C.border),
              ),
              child: ListTile(
                dense: true,
                leading: UserStatus.presenceIndicator(status, size: 18),
                title: Text(
                  UserStatus.getLabel(status),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? _C.textMain : _C.textMuted,
                  ),
                ),
                trailing: isSelected ? const Icon(Icons.check_rounded, color: _C.primary, size: 18) : null,
                onTap: () {
                  Navigator.pop(context);
                  onStatusSelected(status, null);
                },
              ),
            );
          }),
          const Divider(height: 24, color: _C.border),
          InkWell(
            onTap: () {
              Navigator.pop(context);
              _showCustomStatusDialog(context);
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(border: Border.all(color: _C.border), borderRadius: BorderRadius.circular(12)),
              child: const Row(children: [
                Icon(Icons.edit_outlined, color: _C.textMuted, size: 18),
                SizedBox(width: 12),
                Text('Statut personnalisé', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _C.textMain)),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  void _showCustomStatusDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _C.bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Statut personnalisé', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _C.textMain)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(fontSize: 13, color: _C.textMain),
          decoration: InputDecoration(
            hintText: 'Ex: En réunion, En congé...',
            hintStyle: const TextStyle(fontSize: 12, color: _C.textMuted),
            filled: true,
            fillColor: _C.searchBg,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _C.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _C.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _C.primary)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          maxLength: 50,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler', style: TextStyle(color: _C.textMuted))),
          ElevatedButton(
            onPressed: () {
              final custom = controller.text.trim();
              if (custom.isNotEmpty) {
                onStatusSelected(UserStatus.online, custom);
                Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: _C.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('Définir', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
