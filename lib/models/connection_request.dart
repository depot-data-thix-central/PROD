// lib/models/connection_request.dart
class ConnectionRequest {
  final String id;
  final String senderId;
  final String receiverId;
  final String status; // pending, accepted, rejected, blocked
  final String? message;
  final DateTime createdAt;
  final DateTime? respondedAt;
  final Map<String, dynamic>? sender;
  final Map<String, dynamic>? receiver;

  ConnectionRequest({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.status,
    this.message,
    required this.createdAt,
    this.respondedAt,
    this.sender,
    this.receiver,
  });

  factory ConnectionRequest.fromJson(Map<String, dynamic> json) {
    return ConnectionRequest(
      id: json['id'] ?? '',
      senderId: json['sender_id'] ?? '',
      receiverId: json['receiver_id'] ?? '',
      status: json['status'] ?? 'pending',
      message: json['message'],
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      respondedAt: json['responded_at'] != null
          ? DateTime.parse(json['responded_at'])
          : null,
      sender: json['sender'],
      receiver: json['receiver'],
    );
  }
}
