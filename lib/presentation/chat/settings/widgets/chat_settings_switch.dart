// lib/presentation/chat/settings/widgets/chat_settings_switch.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:thix_id/core/theme/thix_design_policy.dart';

// ============================================================================
// SETTINGS SWITCH WIDGET
// ============================================================================

/// Widget de type "Switch" stylisé pour les paramètres.
///
/// Fonctionnalités :
/// - Titre et sous-titre optionnel
/// - Icône optionnelle à gauche
/// - Feedback haptique au changement
/// - Support de l'état désactivé (`isEnabled`)
/// - Accessibilité complète (Semantics)
class ChatSettingsSwitch extends StatelessWidget {
  /// Titre principal du paramètre
  final String title;

  /// Sous-titre descriptif (optionnel)
  final String? subtitle;

  /// Icône à gauche du titre (optionnel)
  final IconData? icon;

  /// Valeur actuelle du switch (true/false)
  final bool value;

  /// Callback appelé lors du changement de valeur
  final ValueChanged<bool> onChanged;

  /// Indique si le switch est interactif (défaut: true)
  final bool isEnabled;

  const ChatSettingsSwitch({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    required this.value,
    required this.onChanged,
    this.isEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    // Couleur active forcée ThixPolicy (indépendante du thème système)
    final activeColor = ThixPolicy.primary;
    final inactiveColor = ThixPolicy.textMuted.withOpacity(0.4);
    
    return Semantics(
      // Label complet pour les lecteurs d'écran
      label: '$title${subtitle != null ? ", $subtitle" : ""}. ${value ? "Activé" : "Désactivé"}',
      enabled: isEnabled,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: icon != null
            ? Icon(icon, color: isEnabled ? ThixPolicy.primary : ThixPolicy.textMuted.withOpacity(0.3))
            : null,
        title: Text(
          title,
          style: ThixPolicy.bodyStyle.copyWith(
            fontWeight: FontWeight.w600,
            color: isEnabled ? ThixPolicy.textMain : ThixPolicy.textMuted.withOpacity(0.5),
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle!,
                style: ThixPolicy.captionStyle.copyWith(
                  color: isEnabled ? ThixPolicy.textMuted : ThixPolicy.textMuted.withOpacity(0.5),
                ),
              )
            : null,
        trailing: Transform.scale(
          scale: 0.9, // Légèrement plus petit pour un look plus moderne
          child: Switch(
            value: value,
            onChanged: isEnabled
                ? (val) {
                    HapticFeedback.selectionClick(); // Feedback tactile
                    onChanged(val);
                  }
                : null, // Désactive le switch si isEnabled est false
            activeColor: activeColor,
            activeTrackColor: activeColor.withOpacity(0.5),
            inactiveThumbColor: inactiveColor,
            inactiveTrackColor: inactiveColor.withOpacity(0.2),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        onTap: isEnabled
            ? () {
                HapticFeedback.selectionClick();
                onChanged(!value);
              }
            : null,
        enabled: isEnabled, // Grise automatiquement le texte si false
      ),
    );
  }
}
