// lib/services/module_notifications.dart
import 'package:thix_id/services/notification_service.dart';

/// Point d'entrée unique pour créer des notifications depuis n'importe
/// quel module THIX ID. Chaque méthode encapsule le bon `type` (aligné
/// sur NotificationModule.typeKeys) et un format de titre/corps cohérent.
///
/// Sous le capot, chaque appel passe par NotificationService.add(), qui
/// insère en base (déclenchant le push FCM via le Database Webhook) ET
/// affiche un pop local immédiat si l'app est ouverte.
class ModuleNotifications {
  ModuleNotifications._();
  static final ModuleNotifications instance = ModuleNotifications._();

  final NotificationService _service = NotificationService();

  // ═══════════════════════════════════════════════════════════════════
  // THIX CHAT
  // ═══════════════════════════════════════════════════════════════════

  Future<void> chatMessage({
    required String toUid,
    required String senderId,
    required String senderName,
    required String preview,
    required String conversationId,
  }) {
    return _service.add(
      toUid: toUid,
      type: 'chat',
      category: 'messages',
      title: senderName,
      body: preview,
      senderId: senderId,
      route: '/chat/c/$conversationId',
      data: {'conversation_id': conversationId},
    );
  }

  Future<void> callMissed({
    required String toUid,
    required String callerId,
    required String callerName,
    required bool isVideo,
  }) {
    return _service.add(
      toUid: toUid,
      type: 'call_missed',
      category: 'messages',
      title: 'Appel manqué',
      body: isVideo
          ? '$callerName a tenté de vous appeler en vidéo'
          : '$callerName a tenté de vous appeler',
      senderId: callerId,
      route: '/chat',
      priority: 2,
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // THIX PRO (Réseau)
  // ═══════════════════════════════════════════════════════════════════

  Future<void> like({
    required String toUid,
    required String senderId,
    required String senderName,
    required String postId,
  }) {
    return _service.add(
      toUid: toUid,
      type: 'like',
      category: 'network',
      title: 'THIX PRO',
      body: '$senderName a aimé votre publication.',
      senderId: senderId,
      postId: postId,
      route: '/network/post/$postId',
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
      category: 'network',
      title: senderName,
      body: commentPreview,
      senderId: senderId,
      postId: postId,
      route: '/network/post/$postId',
    );
  }

  Future<void> commentReply({
    required String toUid,
    required String senderId,
    required String senderName,
    required String postId,
    required String commentPreview,
  }) {
    return _service.add(
      toUid: toUid,
      type: 'comment_reply',
      category: 'network',
      title: senderName,
      body: 'a répondu à votre commentaire : $commentPreview',
      senderId: senderId,
      postId: postId,
      route: '/network/post/$postId',
    );
  }

  Future<void> commentLike({
    required String toUid,
    required String senderId,
    required String senderName,
    required String postId,
  }) {
    return _service.add(
      toUid: toUid,
      type: 'comment_like',
      category: 'network',
      title: 'THIX PRO',
      body: '$senderName a aimé votre commentaire.',
      senderId: senderId,
      postId: postId,
      route: '/network/post/$postId',
    );
  }

  Future<void> repost({
    required String toUid,
    required String senderId,
    required String senderName,
    required String postId,
  }) {
    return _service.add(
      toUid: toUid,
      type: 'repost',
      category: 'network',
      title: 'THIX PRO',
      body: '$senderName a republié votre publication.',
      senderId: senderId,
      postId: postId,
      route: '/network/post/$postId',
    );
  }

  Future<void> mention({
    required String toUid,
    required String senderId,
    required String senderName,
    required String postId,
  }) {
    return _service.add(
      toUid: toUid,
      type: 'mention',
      category: 'network',
      title: 'THIX PRO',
      body: '$senderName vous a mentionné dans une publication.',
      senderId: senderId,
      postId: postId,
      route: '/network/post/$postId',
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
      category: 'network',
      title: 'THIX PRO',
      body: '$senderName a commencé à vous suivre.',
      senderId: senderId,
      route: '/network/profile/$senderId',
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
      category: 'network',
      title: 'THIX PRO',
      body: '$senderName souhaite se connecter avec vous.',
      senderId: senderId,
      route: '/network/connections',
    );
  }

  Future<void> connectionAccepted({
    required String toUid,
    required String senderId,
    required String senderName,
  }) {
    return _service.add(
      toUid: toUid,
      type: 'friend_accepted',
      category: 'network',
      title: 'THIX PRO',
      body: '$senderName a accepté votre demande de connexion.',
      senderId: senderId,
      route: '/network/profile/$senderId',
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // THIX MONEY
  // ═══════════════════════════════════════════════════════════════════

  Future<void> moneyReceived({
    required String toUid,
    required String amountLabel,
    required String fromLabel,
    required String transactionId,
  }) {
    return _service.add(
      toUid: toUid,
      type: 'money',
      category: 'money',
      title: 'THIX MONEY',
      body: 'Vous avez reçu $amountLabel de $fromLabel.',
      route: '/money/transaction/$transactionId',
      priority: 2,
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
      category: 'money',
      title: 'THIX MONEY',
      body: 'Paiement de $amountLabel confirmé.',
      route: '/money/transaction/$transactionId',
    );
  }

  Future<void> moneyRefund({
    required String toUid,
    required String amountLabel,
    required String transactionId,
  }) {
    return _service.add(
      toUid: toUid,
      type: 'refund_processed',
      category: 'money',
      title: 'THIX MONEY',
      body: 'Remboursement de $amountLabel effectué.',
      route: '/money/transaction/$transactionId',
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // THIX MEDIA (Live)
  // ═══════════════════════════════════════════════════════════════════

  Future<void> liveStarted({
    required String toUid,
    required String hostName,
    required String liveId,
  }) {
    return _service.add(
      toUid: toUid,
      type: 'live',
      category: 'live',
      title: 'THIX MEDIA',
      body: '$hostName est en direct maintenant.',
      route: '/media/live/$liveId',
      priority: 1,
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
      category: 'live',
      title: 'THIX MEDIA',
      body: '$requesterName souhaite rejoindre votre direct.',
      route: '/media/live/$liveId',
      priority: 2,
    );
  }

  Future<void> liveInvite({
    required String toUid,
    required String hostName,
    required String liveId,
  }) {
    return _service.add(
      toUid: toUid,
      type: 'live_invite',
      category: 'live',
      title: 'THIX MEDIA',
      body: '$hostName vous invite à rejoindre son direct.',
      route: '/media/live/$liveId',
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // THIX SANTÉ
  // ═══════════════════════════════════════════════════════════════════

  Future<void> healthReminder({
    required String toUid,
    required String reminderLabel,
  }) {
    return _service.add(
      toUid: toUid,
      type: 'health',
      category: 'health',
      title: 'THIX SANTÉ',
      body: reminderLabel,
      route: '/health/dashboard',
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
      category: 'health',
      title: 'THIX SANTÉ',
      body: 'Rendez-vous confirmé : $appointmentLabel',
      route: '/health/appointment/$appointmentId',
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // THIX MARKET
  // ═══════════════════════════════════════════════════════════════════

  Future<void> marketOrderUpdate({
    required String toUid,
    required String orderId,
    required String statusLabel,
  }) {
    return _service.add(
      toUid: toUid,
      type: 'order',
      category: 'market',
      title: 'THIX MARKET',
      body: 'Votre commande est : $statusLabel',
      route: '/market/order/$orderId',
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
      category: 'market',
      title: shopName,
      body: preview,
      route: '/market/shop/$shopId',
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // Opportunités & Emplois
  // ═══════════════════════════════════════════════════════════════════

  Future<void> opportunityMatch({
    required String toUid,
    required String opportunityTitle,
    required String opportunityId,
  }) {
    return _service.add(
      toUid: toUid,
      type: 'opportunity',
      category: 'opportunity',
      title: 'Opportunités',
      body: 'Nouvelle opportunité : $opportunityTitle',
      route: '/opportunities/$opportunityId',
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
      category: 'job',
      title: 'Emplois',
      body: '$jobTitle : $statusLabel',
      route: '/jobs/$jobId',
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // Événements
  // ═══════════════════════════════════════════════════════════════════

  Future<void> eventReminder({
    required String toUid,
    required String eventName,
    required String eventId,
  }) {
    return _service.add(
      toUid: toUid,
      type: 'event',
      category: 'event',
      title: 'Événements',
      body: '$eventName commence bientôt.',
      route: '/events/$eventId',
      priority: 1,
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
      category: 'event',
      title: 'Événements',
      body: '$senderName vous invite à $eventName.',
      route: '/events/$eventId',
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // Formations
  // ═══════════════════════════════════════════════════════════════════

  Future<void> formationNewLesson({
    required String toUid,
    required String courseTitle,
    required String courseId,
  }) {
    return _service.add(
      toUid: toUid,
      type: 'formation',
      category: 'formation',
      title: 'Formations',
      body: 'Nouvelle leçon disponible : $courseTitle',
      route: '/education/course/$courseId',
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
      category: 'formation',
      title: 'Formations',
      body: 'Félicitations ! Votre certificat pour "$courseTitle" est prêt.',
      route: '/education/course/$courseId/certificate',
      priority: 1,
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // Réservation
  // ═══════════════════════════════════════════════════════════════════

  Future<void> reservationConfirmed({
    required String toUid,
    required String label,
    required String reservationId,
  }) {
    return _service.add(
      toUid: toUid,
      type: 'reservation',
      category: 'reservation',
      title: 'Réservation',
      body: 'Réservation confirmée : $label',
      route: '/reservation/$reservationId',
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // Mon Pays
  // ═══════════════════════════════════════════════════════════════════

  Future<void> countryAlert({
    required String toUid,
    required String message,
  }) {
    return _service.add(
      toUid: toUid,
      type: 'country',
      category: 'country',
      title: 'Mon Pays',
      body: message,
      route: '/country',
      priority: 2,
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // THIX SOS
  // ═══════════════════════════════════════════════════════════════════

  Future<void> sosAlert({
    required String toUid,
    required String message,
  }) {
    return _service.add(
      toUid: toUid,
      type: 'sos',
      category: 'sos',
      title: 'THIX SOS',
      body: message,
      route: '/sos',
      priority: 3,
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // THIX DOC
  // ═══════════════════════════════════════════════════════════════════

  Future<void> documentVerified({
    required String toUid,
    required String documentLabel,
  }) {
    return _service.add(
      toUid: toUid,
      type: 'document',
      category: 'doc',
      title: 'THIX DOC',
      body: '$documentLabel a été vérifié.',
      route: '/doc',
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // THIX IA
  // ═══════════════════════════════════════════════════════════════════

  Future<void> iaResponseReady({
    required String toUid,
    required String preview,
  }) {
    return _service.add(
      toUid: toUid,
      type: 'ia',
      category: 'ia',
      title: 'THIX IA',
      body: preview,
      route: '/ia',
    );
  }
}
