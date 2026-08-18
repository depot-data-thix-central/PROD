// lib/presentation/thix_weeding/providers/guest_menu_provider.dart
import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/guest_action_model.dart';
import 'wedding_provider.dart';

part 'guest_menu_provider.g.dart';

/// Menu dynamique scalable.
/// On peut filtrer selon la config du mariage (ex: cadeaux désactivés)
/// On peut ajouter des badges temps réel (ex: 3 annonces)
@riverpod
List<GuestAction> guestMenu(GuestMenuRef ref, String weddingId) {
  // On regarde le mariage pour savoir quoi afficher
  final weddingAsync = ref.watch(guestWeddingProvider(weddingId));
  final hasAnnouncement = weddingAsync.value?.announcement.isNotEmpty ?? false;

  return [
    const GuestAction(
      id: GuestActionId.invitation,
      title: 'Invitation',
      subtitle: 'Voir les détails',
      icon: Icons.mail_outline,
      routeName: 'invitation',
      bgColor: Color(0xFFFEEFF0),
      iconColor: Color(0xFFE25A6A),
    ),
    const GuestAction(
      id: GuestActionId.programme,
      title: 'Programme',
      subtitle: 'Déroulé de la journée',
      icon: Icons.calendar_today_outlined,
      routeName: 'programme',
      bgColor: Color(0xFFFEF5E0),
      iconColor: Color(0xFFE68A00),
    ),
    const GuestAction(
      id: GuestActionId.lieu,
      title: 'Lieu & Accès',
      subtitle: 'Itinéraire & infos',
      icon: Icons.location_on_outlined,
      routeName: 'lieu',
      bgColor: Color(0xFFE6F4EA),
      iconColor: Color(0xFF4A8C6B),
    ),
    GuestAction(
      id: GuestActionId.rsvp,
      title: 'RSVP',
      subtitle: 'Confirmer ma présence',
      icon: Icons.people_outline,
      routeName: 'rsvp',
      badge: null,
      bgColor: const Color(0xFFF3E8FF),
      iconColor: const Color(0xFF9B6BFF),
    ),
    const GuestAction(
      id: GuestActionId.cadeaux,
      title: 'Liste de cadeaux',
      subtitle: 'Voir & contribuer',
      icon: Icons.card_giftcard_outlined,
      routeName: 'cadeaux',
      bgColor: Color(0xFFFFF4CC),
      iconColor: Color(0xFFC49A00),
    ),
    const GuestAction(
      id: GuestActionId.galerie,
      title: 'Galerie',
      subtitle: 'Photos & vidéos',
      icon: Icons.photo_library_outlined,
      routeName: 'galerie',
      bgColor: Color(0xFFE3EEFF),
      iconColor: Color(0xFF5B8DEF),
    ),
    const GuestAction(
      id: GuestActionId.livreOr,
      title: 'Livre d’or',
      subtitle: 'Laisser un message',
      icon: Icons.edit_note_outlined,
      routeName: 'livre-or',
      bgColor: Color(0xFFFFE6E9),
      iconColor: Color(0xFFD46A6A),
    ),
    GuestAction(
      id: GuestActionId.infos,
      title: 'Infos',
      subtitle: 'Annonces, FAQ',
      icon: Icons.info_outline,
      routeName: 'infos',
      badge: hasAnnouncement ? '3' : null, // badge dynamique prod
      bgColor: const Color(0xFFF0F0F0),
      iconColor: const Color(0xFF6B6B6B),
    ),
  ];
}
