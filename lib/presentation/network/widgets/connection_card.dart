import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;

class ConnectionCard extends StatelessWidget {
  final String userId;
  final String displayName;
  final String? photoUrl;
  final String profession;
  final String? bio;
  final String connectedAt;
  final VoidCallback? onTap;
  final VoidCallback? onMessageTap;
  final VoidCallback? onRemoveTap;

  const ConnectionCard({
    super.key,
    required this.userId,
    required this.displayName,
    this.photoUrl,
    required this.profession,
    this.bio,
    required this.connectedAt,
    this.onTap,
    this.onMessageTap,
    this.onRemoveTap,
  });

  String _timeAgo(String iso) {
    try { return timeago.format(DateTime.parse(iso), locale: 'fr'); }
    catch (_) { return 'Récemment'; }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            // Avatar sans CachedAvatar
            CircleAvatar(
              radius: 30,
              backgroundColor: Colors.grey.shade200,
              child: ClipOval(
                child: photoUrl!= null && photoUrl!.isNotEmpty
               ? Image.network(photoUrl!, width: 60, height: 60, fit: BoxFit.cover, errorBuilder: (_,__,___)=> Text(displayName.isNotEmpty? displayName[0].toUpperCase() : '?', style: TextStyle(fontWeight: FontWeight.bold)))
                : Text(displayName.isNotEmpty? displayName[0].toUpperCase() : '?', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(displayName, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF1A1A2E)), maxLines: 1, overflow: TextOverflow.ellipsis)),
                Container(width: 8, height: 8, decoration: BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
              ]),
              const SizedBox(height: 2),
              Text(profession, style: TextStyle(fontSize: 13, color: Colors.grey.shade600), maxLines: 1, overflow: TextOverflow.ellipsis),
              if (bio!= null && bio!.isNotEmpty)...[
                const SizedBox(height: 2),
                Text(bio!, style: TextStyle(fontSize: 12, color: Colors.grey.shade500), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
              const SizedBox(height: 4),
              Text('Connecté ${_timeAgo(connectedAt)}', style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
            ])),
            Row(children: [
              IconButton(icon: Icon(Icons.message_outlined, size: 20, color: Color(0xFFD4AF37)), onPressed: onMessageTap, padding: EdgeInsets.zero, constraints: BoxConstraints()),
              const SizedBox(width: 8),
              IconButton(icon: Icon(Icons.more_vert, size: 20, color: Colors.grey), onPressed: ()=> _showPopupMenu(context), padding: EdgeInsets.zero, constraints: BoxConstraints()),
            ]),
          ]),
        ),
      ),
    );
  }

  void _showPopupMenu(BuildContext context) {
    showModalBottomSheet(context: context, shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const SizedBox(height: 8),
      Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4))),
      const SizedBox(height: 16),
      ListTile(leading: Icon(Icons.person_outline, color: Color(0xFF1A1A2E)), title: Text('Voir le profil'), onTap: (){ Navigator.pop(context); onTap?.call(); }),
      ListTile(leading: Icon(Icons.message_outlined, color: Color(0xFF1A1A2E)), title: Text('Envoyer un message'), onTap: (){ Navigator.pop(context); onMessageTap?.call(); }),
      const Divider(height: 1),
      ListTile(leading: Icon(Icons.person_remove_outlined, color: Colors.red), title: Text('Retirer', style: TextStyle(color: Colors.red)), onTap: (){ Navigator.pop(context); onRemoveTap?.call(); }),
      const SizedBox(height: 8),
    ])));
  }
}
