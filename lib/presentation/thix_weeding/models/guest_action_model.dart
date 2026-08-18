// lib/presentation/thix_weeding/models/guest_action_model.dart
import 'package:flutter/material.dart';

enum GuestActionId { invitation, programme, lieu, rsvp, cadeaux, galerie, livreOr, infos }

@immutable
class GuestAction {
  final GuestActionId id;
  final String title;
  final String subtitle;
  final IconData icon;
  final String routeName;
  final String? badge;
  final Color bgColor;
  final Color iconColor;
  final bool isEnabled;

  const GuestAction({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.routeName,
    this.badge,
    required this.bgColor,
    required this.iconColor,
    this.isEnabled = true,
  });

  GuestAction copyWith({String? badge, bool? isEnabled}) {
    return GuestAction(
      id: id,
      title: title,
      subtitle: subtitle,
      icon: icon,
      routeName: routeName,
      badge: badge ?? this.badge,
      bgColor: bgColor,
      iconColor: iconColor,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }
}
