import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thix_id/features/auth/presentation/providers/auth_provider.dart'; // ton authProvider

class ProfileHeaderCard extends ConsumerWidget {
  final VoidCallback? onEditPressed;
  final VoidCallback? onPhotoPressed;
  final VoidCallback? onVideoPressed;
  final VoidCallback? onDocumentPressed;
  final VoidCallback? onEventPressed;
  final VoidCallback? onJobPressed;
  final VoidCallback? onStoryPressed;

  const ProfileHeaderCard({
    super.key,
    this.onEditPressed,
    this.onPhotoPressed,
    this.onVideoPressed,
    this.onDocumentPressed,
    this.onEventPressed,
    this.onJobPressed,
    this.onStoryPressed,
  });

  String _formatTitle(String? title) {
    if (title == null || title.isEmpty) return 'Partagez votre expertise';
    return title.length > 40 ? '${title.substring(0, 37)}...' : title;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider); // remplace par ton provider
    final user = userAsync.value;
    
    final userName = user?.displayName ?? 'Utilisateur';
    final userTitle = _formatTitle(user?.profession);
    final skills = user?.skills ?? [];
    final hasAvatar = user?.photoUrl != null && user!.photoUrl!.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF0B1B3D), Color(0xFF1A2D56)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Stack(children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: Colors.white24,
              child: ClipOval(
                child: hasAvatar
                 ? Image.network(user!.photoUrl!, width: 64, height: 64, fit: BoxFit.cover, errorBuilder: (_,__,___)=> Icon(Icons.person, size: 32, color: Colors.white))
                  : Icon(Icons.person, size: 32, color: Colors.white),
              ),
            ),
            if (onEditPressed != null)
              Positioned(bottom: 0, right: 0, child: GestureDetector(onTap: onEditPressed, child: Container(padding: EdgeInsets.all(4), decoration: BoxDecoration(color: Color(0xFFD4AF37), shape: BoxShape.circle), child: Icon(Icons.edit, size: 12, color: Color(0xFF0B1B3D))))),
          ]),
          SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(userName, style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
            SizedBox(height: 2),
            Text(userTitle, style: TextStyle(color: Colors.white70, fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis),
          ])),
        ]),
        if (skills.isNotEmpty)...[
          SizedBox(height: 12),
          Wrap(spacing: 6, runSpacing: 6, children: skills.take(3).map((s){
            final name = (s is Map? s['name'] : s).toString();
            if(name.isEmpty) return SizedBox.shrink();
            return Container(padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(16)), child: Text(name, style: TextStyle(fontSize: 9, color: Colors.white70)));
          }).toList()),
        ],
        SizedBox(height: 12),
        Text('Que souhaitez-vous partager aujourd\'hui ?', style: TextStyle(color: Colors.white70, fontSize: 11)),
        SizedBox(height: 10),
        // FIX: Wrap au lieu de Row pour éviter overflow 6 boutons
        Wrap(spacing: 6, runSpacing: 6, children: [
          _btn(Icons.photo_camera, 'Photo', onPhotoPressed),
          _btn(Icons.videocam, 'Vidéo', onVideoPressed),
          _btn(Icons.insert_drive_file, 'Document', onDocumentPressed),
          _btn(Icons.event, 'Événement', onEventPressed),
          _btn(Icons.work, 'Offre', onJobPressed),
          _btn(Icons.auto_awesome, 'Story', onStoryPressed),
        ]),
      ]),
    );
  }

  Widget _btn(IconData icon, String label, VoidCallback? onTap) {
    return SizedBox(
      width: 74,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(side: BorderSide(color: Color(0xFFD4AF37)), padding: EdgeInsets.symmetric(vertical: 7), minimumSize: Size.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
        child: Column(children: [Icon(icon, size: 16, color: Color(0xFFD4AF37)), SizedBox(height: 2), Text(label, style: TextStyle(fontSize: 9, color: Colors.white))]),
      ),
    );
  }
}
