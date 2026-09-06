// lib/models/event_booking.dart

class EventBooking {
  final String id;
  final String eventId;
  final String userId;
  final int ticketQuantity;
  final double totalPrice;
  final String? paymentMethod;
  final String paymentStatus;
  final String ticketCode;
  final String qrCode;
  final String status;
  final DateTime bookingDate;

  // Catégorie du billet (ex: VIP, GOLD, Standard)
  final String ticketCategory;
  
  // NOUVEAU : Devise de la transaction (ex: $, FC, etc.)
  final String? currency;

  // Champs additionnels venant de la jointure avec la table 'events'
  final String eventTitle;
  final String? eventImageUrl;
  final DateTime eventDate;
  final String eventLocation;

  EventBooking({
    required this.id,
    required this.eventId,
    required this.userId,
    required this.ticketQuantity,
    required this.totalPrice,
    this.paymentMethod,
    required this.paymentStatus,
    required this.ticketCode,
    required this.qrCode,
    required this.status,
    required this.bookingDate,
    this.ticketCategory = 'Standard',
    this.currency, // Initialisation de la devise
    this.eventTitle = '',
    this.eventImageUrl,
    required this.eventDate,
    this.eventLocation = '',
  });

  factory EventBooking.fromJson(Map<String, dynamic> json) {
    // Récupération sécurisée si les données viennent d'une relation imbriquée Supabase (ex: 'events': { ... })
    final eventData = json['events'] is Map<String, dynamic> ? json['events'] as Map<String, dynamic> : null;

    // Gestion spécifique pour les dates (cherche 'event_date', 'starts_at', ou 'start_date')
    DateTime parseDate(dynamic val) {
      if (val == null) return DateTime.now();
      return DateTime.tryParse(val.toString()) ?? DateTime.now();
    }

    DateTime? resolvedEventDate;
    if (json['event_date'] != null) {
      resolvedEventDate = parseDate(json['event_date']);
    } else if (eventData != null) {
      resolvedEventDate = parseDate(eventData['starts_at'] ?? eventData['start_date'] ?? eventData['date']);
    }

    // Gestion de l'image (cherche 'event_image_url', 'image_url', ou 'cover_image_path')
    String? resolvedImageUrl = json['event_image_url']?.toString() ?? 
        eventData?['image_url']?.toString() ?? 
        eventData?['cover_image_path']?.toString();

    // Gestion du titre
    String resolvedTitle = json['event_title']?.toString() ?? 
        eventData?['title']?.toString() ?? 
        'Événement';

    // Gestion du lieu
    String resolvedLocation = json['event_location']?.toString() ?? 
        eventData?['location']?.toString() ?? 
        eventData?['place']?.toString() ?? 
        'Lieu inconnu';

    // Gestion de la catégorie du billet
    String resolvedCategory = json['ticket_category']?.toString() ?? 
        json['category']?.toString() ?? 
        eventData?['category']?.toString() ?? 
        'Standard';

    // NOUVEAU : Gestion dynamique de la devise
    String resolvedCurrency = json['currency']?.toString() ??
        json['price_currency']?.toString() ??
        eventData?['price_currency']?.toString() ??
        eventData?['currency']?.toString() ??
        '';

    return EventBooking(
      id: json['id']?.toString() ?? '',
      eventId: json['event_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      ticketQuantity: int.tryParse(json['ticket_quantity']?.toString() ?? '1') ?? 1,
      totalPrice: double.tryParse(json['total_price']?.toString() ?? '0') ?? 0.0,
      paymentMethod: json['payment_method']?.toString(),
      paymentStatus: json['payment_status']?.toString() ?? 'paid',
      ticketCode: json['ticket_code']?.toString() ?? '',
      qrCode: json['qr_code']?.toString() ?? '',
      status: json['status']?.toString() ?? 'confirmed',
      bookingDate: json['booking_date'] != null 
          ? DateTime.tryParse(json['booking_date'].toString()) ?? DateTime.now()
          : DateTime.now(),
      
      ticketCategory: resolvedCategory,
      currency: resolvedCurrency, // Injection de la devise
      
      eventTitle: resolvedTitle,
      eventImageUrl: resolvedImageUrl,
      eventDate: resolvedEventDate ?? DateTime.now(),
      eventLocation: resolvedLocation,
    );
  }
}
