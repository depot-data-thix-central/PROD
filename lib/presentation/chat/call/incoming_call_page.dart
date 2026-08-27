// lib/presentation/chat/call/incoming_call_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../models/chat/call_invite.dart';
import '../../thix_sos/pages/chambre_crise_secours_page.dart';
import '../../thix_sos/services/sos_service.dart';
import 'call_page.dart';
import 'providers/call_provider.dart';

class IncomingCallPage extends ConsumerWidget {
  final CallInvite invite;
  final String? callerName;
  final String? callerAvatar;

  const IncomingCallPage({
    super.key,
    required this.invite,
    this.callerName,
    this.callerAvatar,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = callerName ?? invite.callerName ?? 'Appel entrant';
    final isVideo = invite.isVideo;

    return Scaffold(
      backgroundColor: const Color(0xFF0A1F44),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            CircleAvatar(
              radius: 60,
              backgroundColor: Colors.white24,
              backgroundImage:
                  callerAvatar != null ? NetworkImage(callerAvatar!) : null,
              child: callerAvatar == null
                  ? const Icon(Icons.person, size: 60, color: Colors.white)
                  : null,
            ),
            const SizedBox(height: 24),
            Text(
              name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isVideo ? 'Appel vidéo entrant' : 'Appel audio entrant',
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(bottom: 48),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _CircleAction(
                    color: const Color(0xFFEF4444),
                    icon: Icons.call_end,
                    label: 'Refuser',
                    onTap: () async {
                      await ref
                          .read(callProvider.notifier)
                          .rejectIncoming(invite.id);
                      if (context.mounted) Navigator.pop(context);
                    },
                  ),
                  _CircleAction(
                    color: const Color(0xFF7C3AED),
                    icon: Icons.shield,
                    label: 'Chambre',
                    onTap: () async {
                      final incident = await SosService()
                          .findActiveByVictim(invite.callerId);
                      if (!context.mounted) return;
                      if (incident == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Pas de SOS actif lié à cet appel',
                            ),
                          ),
                        );
                        return;
                      }
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChambreCriseSecoursPage(
                            incidentId: incident.id,
                            victimUserId: invite.callerId,
                          ),
                        ),
                      );
                    },
                  ),
                  _CircleAction(
                    color: const Color(0xFF22C55E),
                    icon: isVideo ? Icons.videocam : Icons.call,
                    label: 'Accepter',
                    onTap: () async {
                      final myId =
                          Supabase.instance.client.auth.currentUser?.id ?? '';
                      await ref.read(callProvider.notifier).acceptIncoming(
                            invite: invite,
                            myUserId: myId,
                            callerName: name,
                            callerAvatar: callerAvatar,
                          );
                      if (!context.mounted) return;
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const CallPage()),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleAction extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _CircleAction({
    required this.color,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(40),
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 32),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white70)),
      ],
    );
  }
}
