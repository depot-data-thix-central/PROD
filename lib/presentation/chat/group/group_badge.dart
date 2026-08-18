import 'package:flutter/material.dart';

/// Widget de badge pour afficher les rôles dans un groupe.
/// Styles : admin (or), modérateur (bleu), membre (gris clair), bot (gris).
class GroupBadge extends StatelessWidget {
  final String role; // 'admin', 'moderator', 'member', 'bot'
  final double fontSize;
  final bool isCompact;

  const GroupBadge({
    super.key,
    required this.role,
    this.fontSize = 10,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final (color, text, icon) = _getBadgeStyle(role);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 6 : 10,
        vertical: isCompact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: fontSize + 2,
              color: color,
            ),
            if (!isCompact) const SizedBox(width: 4),
          ],
          if (!isCompact || icon == null)
            Text(
              text,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
                color: color,
                letterSpacing: 0.3,
              ),
            ),
        ],
      ),
    );
  }

  (Color color, String text, IconData? icon) _getBadgeStyle(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return (
          const Color(0xFFE3B23C), // Or THIX
          'Admin',
          Icons.star_rounded
        );
      case 'moderator':
        return (
          const Color(0xFF2D6CDF), // Bleu THIX
          'Modérateur',
          Icons.shield_rounded
        );
      case 'bot':
        return (
          const Color(0xFF6B7690), // Gris
          'Bot',
          Icons.smart_toy_rounded
        );
      case 'member':
      default:
        return (
          const Color(0xFF6B7690), // Gris
          'Membre',
          null
        );
    }
  }
}
