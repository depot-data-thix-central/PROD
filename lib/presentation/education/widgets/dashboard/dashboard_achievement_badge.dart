// lib/presentation/education/widgets/dashboard/dashboard_achievement_badge.dart
import 'package:flutter/material.dart';

class _C {
  static const textMain = Color(0xFF0F172A);
  static const textMuted = Color(0xFF64748B);
  static const gold = Color(0xFFE3B23C);
  static const green = Color(0xFF10B981);
  
  // Couleurs pour l'état verrouillé
  static const lockedBg = Color(0xFFF8FAFC);
  static const lockedBorder = Color(0xFFE2E8F0);
  static const lockedIconBg = Color(0xFFF1F5F9);
  static const lockedText = Color(0xFF94A3B8);
}

class DashboardAchievementBadge extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color? color;
  final bool isUnlocked;
  final VoidCallback? onTap;

  const DashboardAchievementBadge({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.color,
    this.isUnlocked = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color badgeColor = color ?? _C.gold;
    final bool locked = !isUnlocked;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: locked ? _C.lockedBg : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: locked ? _C.lockedBorder : badgeColor.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: locked
            ? null
            : [
                BoxShadow(
                  color: const Color(0xFF0A1F44).withOpacity(0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          splashColor: badgeColor.withOpacity(0.1),
          highlightColor: badgeColor.withOpacity(0.05),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: locked ? _C.lockedIconBg : badgeColor.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: locked ? _C.lockedText : badgeColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: locked ? _C.lockedText : _C.textMain,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        locked ? '🔒 Verrouillé' : subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: locked ? _C.lockedText : _C.textMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (!locked)
                  const Padding(
                    padding: EdgeInsets.only(left: 8.0),
                    child: Icon(
                      Icons.check_circle_rounded,
                      color: _C.green,
                      size: 20,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
