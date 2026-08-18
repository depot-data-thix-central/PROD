// lib/models/ticket_tier.dart
class TicketTier {
  final String name;
  final double price;
  final int capacity;
  final int? remaining;

  TicketTier({
    required this.name,
    required this.price,
    required this.capacity,
    this.remaining,
  });

  factory TicketTier.fromJson(Map<String, dynamic> json) {
    return TicketTier(
      name: json['name']?.toString() ?? 'Standard',
      // 🟢 Force la conversion en double, même si c'est un texte ("50" devient 50.0)
      price: double.tryParse(json['price'].toString()) ?? 0.0,
      // 🟢 Force la conversion en entier
      capacity: int.tryParse(json['capacity'].toString()) ?? 0,
      remaining: json['remaining'] != null ? int.tryParse(json['remaining'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'price': price,
      'capacity': capacity,
      if (remaining != null) 'remaining': remaining,
    };
  }
}
