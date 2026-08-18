// lib/presentation/thix_urgent/widgets/actions/green_action_button.dart
import 'package:flutter/material.dart';
import '../../controllers/urgent_controller.dart';

class GreenActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final EmergencyType type;
  final bool isSelected;
  final VoidCallback onTap;

  const GreenActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.type,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 76,
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF16A34A) : const Color(0xFF22C55E),
            borderRadius: BorderRadius.circular(18),
            border: isSelected ? Border.all(color: Colors.white, width: 2.5) : null,
            boxShadow: [
              BoxShadow(
                color: Colors.green.withOpacity(isSelected ? 0.5 : 0.3),
                blurRadius: isSelected ? 14 : 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: isSelected ? 28 : 26),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isSelected ? 9 : 8.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.3,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
