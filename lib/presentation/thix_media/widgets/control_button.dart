import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final Color? backgroundColor;
  final Color? iconColor;
  final String? tooltip;
  final bool isEnabled;
  final bool isActive;
  final double size;

  const ControlButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.backgroundColor,
    this.iconColor,
    this.tooltip,
    this.isEnabled = true,
    this.isActive = false,
    this.size = 52,
  });

  @override Widget build(BuildContext context){
    final theme = Theme.of(context);
    final bg = !isEnabled? Colors.grey.shade400 : isActive? (backgroundColor?? theme.primaryColor) : (backgroundColor?? const Color(0xFF1E1E28));
    final fg = iconColor?? Colors.white;

    return Semantics(
      button: true,
      enabled: isEnabled,
      label: tooltip??'',
      child: Tooltip(
        message: tooltip??'',
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
            boxShadow: isEnabled && isActive? [BoxShadow(color: bg.withOpacity(0.4), blurRadius: 12, offset: const Offset(0,4))] : null,
            border: !isActive? Border.all(color: Colors.white.withOpacity(0.08)) : null,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(100),
              onTap: isEnabled? (){ HapticFeedback.lightImpact(); onPressed(); } : null,
              child: Center(child: Icon(icon, color: fg, size: 22)),
            ),
          ),
        ),
      ),
    );
  }
}
