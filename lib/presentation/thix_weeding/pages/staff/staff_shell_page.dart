import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'staff_dashboard_page.dart';
import 'invités/guest_list_page.dart';
import 'messages/staff_messages_page.dart';
import 'parametres/settings_page.dart';
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
      return; // ne change JAMAIS l'index vers 2
    }
    setState(() => _index = i);
  }

  void _showAddSheet() {
    final id = widget.weddingId;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.person_add_outlined),
              title: const Text('Ajouter un invité'),
              onTap: () {
                Navigator.pop(context);
                context.push('/thix-weeding/staff/$id/invites/add');
              },
            ),
            ListTile(
              leading: const Icon(Icons.store_outlined),
              title: const Text('Ajouter un prestataire'),
              onTap: () {
                Navigator.pop(context);
                context.push('/thix-weeding/staff/$id/prestataires/add');
              },
            ),
            ListTile(
              leading: const Icon(Icons.task_alt_outlined),
              title: const Text('Ajouter une tâche'),
              onTap: () {
                Navigator.pop(context);
                context.push('/thix-weeding/staff/$id/checklist/add');
              },
            ),
            ListTile(
              leading: const Icon(Icons.payments_outlined),
              title: const Text('Ajouter un paiement'),
              onTap: () {
                Navigator.pop(context);
                context.push('/thix-weeding/staff/$id/paiements/add');
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final unread = ref.watch(messagesProvider(widget.weddingId)).maybeWhen(
          data: (msgs) => msgs
              .where((m) => !m.isRead && m.senderType == 'guest')
              .length,
          orElse: () => 0,
        );

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: IndexedStack(
        index: _index,
        children: [
          // 0 Dashboard
          StaffDashboardPage(weddingId: widget.weddingId),
          // 1 Invités
          GuestListPage(weddingId: widget.weddingId),
          // 2 placeholder (jamais affiché)
          const SizedBox.shrink(),
          // 3 Messages
          StaffMessagesPage(weddingId: widget.weddingId),
          // 4 Paramètres
          SettingsPage(weddingId: widget.weddingId),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
        ),
        child: BottomNavigationBar(
          currentIndex: _index,
          onTap: _onTap,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          elevation: 0,
          selectedItemColor: const Color(0xFF0B3B8F),
          unselectedItemColor: const Color(0xFF6B7280),
          selectedFontSize: 11,
          unselectedFontSize: 11,
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard),
              label: 'Dashboard',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.people_outline),
              label: 'Invités',
            ),
            BottomNavigationBarItem(
              icon: Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: Color(0xFF0B3B8F),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 22),
              ),
              label: 'Ajouter',
            ),
            BottomNavigationBarItem(
              icon: unread > 0
                  ? Badge(
                      label: Text('$unread'),
                      child: const Icon(Icons.chat_bubble_outline),
                    )
                  : const Icon(Icons.chat_bubble_outline),
              label: 'Messages',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              label: 'Paramètres',
            ),
          ],
        ),
      ),
    );
  }
}
