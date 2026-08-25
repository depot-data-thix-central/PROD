// lib/presentation/thix_ia/widgets/phase_switcher.dart
import 'package:flutter/material.dart';
import '../../../../core/theme/thix_design_policy.dart';

class PhaseSwitcher extends StatelessWidget {
  const PhaseSwitcher({
    super.key,
    required this.isExecutionMode,
    required this.onModeChanged,
  });

  final bool isExecutionMode;
  final ValueChanged<bool> onModeChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B), // Couleur sombre façon THIX Urgence / Mode sombre
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Bouton ANALYSE
          Expanded(
            child: GestureDetector(
              onTap: () => onModeChanged(false),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: !isExecutionMode 
                      ? ThixPolicy.primary.withOpacity(0.2) // Fond actif
                      : Colors.transparent, // Fond inactif
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.analytics_outlined,
                      size: 16,
                      color: !isExecutionMode ? ThixPolicy.primary : Colors.grey.shade500,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'ANALYSE',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: !isExecutionMode ? ThixPolicy.primary : Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Bouton EXÉCUTION
          Expanded(
            child: GestureDetector(
              onTap: () => onModeChanged(true),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isExecutionMode 
                      ? const Color(0xFFEF4444).withOpacity(0.2) // Rouge/Orange façon "SOS" de ton image
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.rocket_launch_rounded,
                      size: 16,
                      color: isExecutionMode ? const Color(0xFFEF4444) : Colors.grey.shade500,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'EXÉCUTION',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isExecutionMode ? const Color(0xFFEF4444) : Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
