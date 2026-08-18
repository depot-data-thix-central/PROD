// lib/models/event_waiting_queue.dart
class WaitingQueue {
  final String id;
  final String eventId;
  final String userId;
  final int position;
  final int quantity;
  final DateTime joinedAt;
  final String status; // waiting, processing, completed, expired
  final DateTime? processedAt;

  WaitingQueue({
    required this.id,
    required this.eventId,
    required this.userId,
    required this.position,
    required this.quantity,
    required this.joinedAt,
    required this.status,
    this.processedAt,
  });

  factory WaitingQueue.fromJson(Map<String, dynamic> json) {
    return WaitingQueue(
      id: json['id'],
      eventId: json['event_id'],
      userId: json['user_id'],
      position: json['position'],
      quantity: json['quantity'],
      joinedAt: DateTime.parse(json['joined_at']),
      status: json['status'],
      processedAt: json['processed_at'] != null 
          ? DateTime.parse(json['processed_at']) 
          : null,
    );
  }

  String get estimatedWaitTime {
    // Estimation: 30 secondes par personne
    final minutes = (position * 0.5).round();
    if (minutes < 1) return 'Moins d\'une minute';
    if (minutes == 1) return 'Environ 1 minute';
    return 'Environ $minutes minutes';
  }

  bool get isWaiting => status == 'waiting';
  bool get isProcessing => status == 'processing';
  bool get isCompleted => status == 'completed';
  bool get isExpired => status == 'expired';
}
