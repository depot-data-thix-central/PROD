// lib/presentation/thix_weeding/models/rsvp_model.dart
import 'package:flutter/foundation.dart';

@immutable
class RsvpEntity {
  final String weddingId;
  final String guestName;
  final String status; // yes, no, maybe
  final int count;
  final String message;
  final DateTime createdAt;

  const RsvpEntity({
    required this.weddingId,
    required this.guestName,
    required this.status,
    required this.count,
    required this.message,
    required this.createdAt,
  });

  Map<String, dynamic> toPayload() => {
    'wedding_id': weddingId,
    'guest_name': guestName.trim(),
    'status': status,
    'count': count,
    'message': message.trim(),
  };
}
