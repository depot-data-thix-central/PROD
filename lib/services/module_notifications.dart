// lib/services/module_notifications.dart
import 'package:thix_id/services/notification_service.dart';

/// Point d'entrée unique pour créer des notifications depuis n'importe
/// quel module THIX ID. Chaque méthode encapsule le bon `type` (aligné
/// sur NotificationModule.typeKeys) et un format de titre/corps cohérent,
/// pour éviter que chaque écran ne recompose ça à la main.
///
/// Sous le capot, chaque appel passe par NotificationService.add(), qui
/// insère en base (déclenchant le push FCM via le Database Webhook) ET
/// affiche un pop local immédiat si l'app est ouverte.
class ModuleNotifications {
  ModuleNotifications._();
  static final ModuleNotifications instance = ModuleNotifications._();

  final NotificationService _service = NotificationService();

  // ─── THIX CHAT ──────────────────────────────────────────────────────

  Future<void> chatMessage({
    required String toUid,
    required String senderName,
    required String preview,
    required String conversationId,
  }) {
    return _service.add(
      toUid: toUid,
      type: 'chat',
      title: senderName,
      body: preview,
      data: {'route': '/chat/c/$conversationId'},
    );
  }

  // ─── THIX PRO (réseau) ──────────────────────────────────────────────

  Future<void> like({
    required String toUid,
    required String senderId,
    required String senderName,
    required String postId,
  }) {
    return _service.add(
      toUid: toUid,
      type: 'like',
      title: 'THIX PRO',
      body: '$senderName a aimé votre publication.',
      senderId: senderId,
      postId: postId,
      data: {'route': '/network/post/$postId'},
    );
  }

  Future<void> comment({
    required String toUid,
    required String senderId,
    required String senderName,
    required String postId,
    required String commentPreview,
  }) {
    return _service.add(
      toUid: toUid,
      type: 'comment',
      title: senderName,
      body: commentPreview,
      senderId: senderId,
      postId: postId,
      data: {'route': '/network/post/$postId'},
    );
  }

  Future<void> follow({
    required String toUid,
    required String senderId,
    required String senderName,
  }) {
    return _service.add(
      toUid: toUid,
      type: 'follow',
      title: 'THIX PRO',
      body: '$senderName a commencé à vous suivre.',
      senderId: senderId,
      data: {'route': '/network/profile/$senderId'},
    );
  }

  Future<void> connectionRequest({
    required String toUid,
    required String senderId,
    required String senderName,
  }) {
    return _service.add(
      toUid: toUid,
      type: 'connection',
      title: 'THIX PRO',
      body: '$senderName souhaite se connecter avec vous.',
      senderId: senderId,
      data: {'route': '/network/connections'},
    );
  }

  // ─── THIX MONEY ─────────────────────────────────────────────────────

  Future<void> moneyReceived({
    required String toUid,
    required String amountLabel,
    required String fromLabel,
    required String transactionId,
  }) {
    return _service.add(
      toUid: toUid,
      type: 'money',
      title: 'THIX MONEY',
      body: 'Vous avez reçu $amountLabel de $fromLabel.',
      data: {'route': '/money/transaction/$transactionId'},
    );
  }

  Future<void> moneyPaymentConfirmed({
    required String toUid,
    required String amountLabel,
    required String transactionId,
  }) {
    return _service.add(
      toUid: toUid,
      type: 'payment',
      title: 'THIX MONEY',
      body: 'Paiement de $amountLabel confirmé.',
      data: {'route': '/money/transaction/$transactionId'},
    );
  }

  // ─── THIX MEDIA (live) ──────────────────────────────────────────────

  Future<void> liveStarted({
    required String toUid,
    required String hostName,
    required String liveId,
  }) {
    return _service.add(
      toUid: toUid,
      type: 'live',
      title: 'THIX MEDIA',
      body: '$hostName est en direct maintenant.',
      data: {'route': '/media/live/$liveId'},
    );
  }

  Future<void> coHostRequest({
    required String toUid,
    required String requesterName,
    required String liveId,
  }) {
    return _service.add(
      toUid: toUid,
      type: 'cohost_request',
      title: 'THIX MEDIA',
      body: '$requesterName souhaite rejoindre votre direct.',
      data: {'route': '/media/live/$liveId'},
    );
  }

  // ─── THIX SANTÉ ─────────────────────────────────────────────────────

  Future<void> healthReminder({
    required String toUid,
    required String reminderLabel,
  }) {
    return _service.add(
      toUid: toUid,
      type: 'health',
      title: 'THIX SANTÉ',
      body: reminderLabel,
      data: {'route': '/health/dashboard'},
    );
  }

  Future<void> healthAppointmentConfirmed({
    required String toUid,
    required String appointmentLabel,
    required String appointmentId,
  }) {
    return _service.add(
      toUid: toUid,
      type: 'thix_sante',
      title: 'THIX SANTÉ',
      body: 'Rendez-vous confirmé : $appointmentLabel',
      data: {'route': '/health/appointment/$appointmentId'},
    );
  }

  // ─── THIX MARKET ────────────────────────────────────────────────────

  Future<void> marketOrderUpdate({
    required String toUid,
    required String orderId,
    required String statusLabel,
  }) {
    return _service.add(
      toUid: toUid,
      type: 'order',
      title: 'THIX MARKET',
      body: 'Votre commande est : $statusLabel',
      data: {'route': '/market/order/$orderId'},
    );
  }

  Future<void> marketNewMessageFromShop({
    required String toUid,
    required String shopName,
    required String preview,
    required String shopId,
  }) {
    return _service.add(
      toUid: toUid,
      type: 'shop',
      title: shopName,
      body: preview,
      data: {'route': '/market/shop/$shopId'},
    );
  }

  // ─── Opportunités & Emplois ─────────────────────────────────────────

  Future<void> opportunityMatch({
    required String toUid,
    required String opportunityTitle,
    required String opportunityId,
  }) {
    return _service.add(
      toUid: toUid,
      type: 'opportunity',
      title: 'Opportunités',
      body: 'Nouvelle opportunité : $opportunityTitle',
      data: {'route': '/opportunities/$opportunityId'},
    );
  }

  Future<void> jobApplicationUpdate({
    required String toUid,
    required String jobTitle,
    required String statusLabel,
    required String jobId,
  }) {
    return _service.add(
      toUid: toUid,
      type: 'job',
      title: 'Emplois',
      body: '$jobTitle : $statusLabel',
      data: {'route': '/jobs/$jobId'},
    );
  }

  // ─── Événements ─────────────────────────────────────────────────────

  Future<void> eventReminder({
    required String toUid,
    required String eventName,
    required String eventId,
  }) {
    return _service.add(
      toUid: toUid,
      type: 'event',
      title: 'Événements',
      body: '$eventName commence bientôt.',
      data: {'route': '/events/$eventId'},
    );
  }

  Future<void> eventInvitation({
    required String toUid,
    required String senderName,
    required String eventName,
    required String eventId,
  }) {
    return _service.add(
      toUid: toUid,
      type: 'event',
      title: 'Événements',
      body: '$senderName vous invite à $eventName.',
      data: {'route': '/events/$eventId'},
    );
  }

  // ─── Formations ─────────────────────────────────────────────────────

  Future<void> formationNewLesson({
    required String toUid,
    required String courseTitle,
    required String courseId,
  }) {
    return _service.add(
      toUid: toUid,
      type: 'formation',
      title: 'Formations',
      body: 'Nouvelle leçon disponible : $courseTitle',
      data: {'route': '/education/course/$courseId'},
    );
  }

  Future<void> certificateIssued({
    required String toUid,
    required String courseTitle,
    required String courseId,
  }) {
    return _service.add(
      toUid: toUid,
      type: 'certificate',
      title: 'Formations',
      body: 'Félicitations ! Votre certificat pour "$courseTitle" est prêt.',
      data: {'route': '/education/course/$courseId/certificate'},
    );
  }

  // ─── Réservation ────────────────────────────────────────────────────

  Future<void> reservationConfirmed({
    required String toUid,
    required String label,
    required String reservationId,
  }) {
    return _service.add(
      toUid: toUid,
      type: 'reservation',
      title: 'Réservation',
      body: 'Réservation confirmée : $label',
      data: {'route': '/reservation/$reservationId'},
    );
  }

  // ─── Mon Pays ───────────────────────────────────────────────────────

  Future<void> countryAlert({
    required String toUid,
    required String message,
  }) {
    return _service.add(
      toUid: toUid,
      type: 'country',
      title: 'Mon Pays',
      body: message,
      data: {'route': '/country'},
    );
  }

  // ─── THIX SOS ───────────────────────────────────────────────────────

  Future<void> sosAlert({
    required String toUid,
    required String message,
  }) {
    return _service.add(
      toUid: toUid,
      type: 'sos',
      title: 'THIX SOS',
      body: message,
      data: {'route': '/sos'},
    );
  }

  // ─── THIX DOC ───────────────────────────────────────────────────────

  Future<void> documentVerified({
    required String toUid,
    required String documentLabel,
  }) {
    return _service.add(
      toUid: toUid,
      type: 'document',
      title: 'THIX DOC',
      body: '$documentLabel a été vérifié.',
      data: {'route': '/doc'},
    );
  }

  // ─── THIX IA ────────────────────────────────────────────────────────

  Future<void> iaResponseReady({
    required String toUid,
    required String preview,
  }) {
    return _service.add(
      toUid: toUid,
      type: 'ia',
      title: 'THIX IA',
      body: preview,
      data: {'route': '/ia'},
    );
  }
}
