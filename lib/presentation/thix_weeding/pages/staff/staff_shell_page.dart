// lib/presentation/thix_weeding/pages/staff/staff_shell_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'staff_dashboard_page.dart';
import 'invités/guest_list_page.dart';
import 'messages/staff_messages_page.dart';
import 'parametres/settings_page.dart';

// CENTRAUX
import 'package:thix_id/presentation/thix_weeding/pages/staff/models/thix_weeding_models.dart';
import 'package:thix_id/presentation/thix_weeding/pages/staff/providers/thix_weeding_providers.dart';

class StaffShellPage extends ConsumerStatefulWidget {
  final String weddingId;
  const StaffShellPage({super.key, required this.weddingId});
  @override
  ConsumerState<StaffShellPage> createState() => _StaffShellPageState();
}

class _StaffShellPageState extends ConsumerState<StaffShellPage> {
  int _index = 0;

  void _onTap(int i) {
    if (i == 2) {
      _showAddSheet();
      return;
    }
    setState(() => _index = i);
  }

  void _showAddSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.person_add), title: const Text('Ajouter un invité'), onTap: () { context.pop(); context.push('/thix-weeding/staff/${widget.weddingId}/invites/add'); }),
          ListTile(leading: const Icon(Icons.store), title: const Text('Ajouter un prestataire'), onTap: () { context.pop(); context.push('/thix-weeding/staff/${widget.weddingId}/prestataires/add'); }),
          ListTile(leading: const Icon(Icons.task), title: const Text('Ajouter une tâche'), onTap: () { context.pop(); context.push('/thix-weeding/staff/${widget.weddingId}/checklist/add'); }),
          ListTile(leading: const Icon(Icons.payments), title: const Text('Ajouter un paiement'), onTap: () { context.pop(); context.push('/thix-weeding/staff/${widget.weddingId}/paiements/add'); }),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(messagesProvider(widget.weddingId));
    final unreadCount = messagesAsync.maybeWhen(data: (List<MessageModel> msgs) => msgs.where((m) => !m.isRead && m.senderType == 'guest').length, orElse: () => 0);

    final pages = [
      StaffDashboardPage(weddingId: widget.weddingId),
      GuestListPage(weddingId: widget.weddingId),
      const SizedBox.shrink(),
      StaffMessagesPage(weddingId: widget.weddingId),
      SettingsPage(weddingId: widget.weddingId),
    ];

    return Scaffold(
      body: pages[_index],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: _onTap,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF0B3B8F),
        unselectedItemColor: const Color(0xFF6B7280),
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          const BottomNavigationBarItem(icon: Icon(Icons.people_outline), label: 'Invités'),
          BottomNavigationBarItem(icon: Container(padding: const EdgeInsets.all(10), decoration: const BoxDecoration(color: Color(0xFF0B3B8F), shape: BoxShape.circle), child: const Icon(Icons.add, color: Colors.white, size: 22)), label: 'Ajouter'),
          BottomNavigationBarItem(icon: unreadCount > 0 ? Badge(label: Text('$unreadCount'), child: const Icon(Icons.chat_bubble_outline)) : const Icon(Icons.chat_bubble_outline), label: 'Messages'),
          const BottomNavigationBarItem(icon: Icon(Icons.settings_outlined), label: 'Paramètres'),
        ],
      ),
    );
  }
}
