import 'dart:convert';

class JobMessage {
  final String id;
  final String jobId;
  final String? applicationId;
  final String senderUserId;
  final String receiverUserId;
  final String body;
  final DateTime createdAt;
  final DateTime updatedAt;

  const JobMessage({
    required this.id,
    required this.jobId,
    required this.applicationId,
    required this.senderUserId,
    required this.receiverUserId,
    required this.body,
    required this.createdAt,
    required this.updatedAt,
  });

  JobMessage copyWith({
    String? id,
    String? jobId,
    String? applicationId,
    String? senderUserId,
    String? receiverUserId,
    String? body,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return JobMessage(
      id: id ?? this.id,
      jobId: jobId ?? this.jobId,
      applicationId: applicationId ?? this.applicationId,
      senderUserId: senderUserId ?? this.senderUserId,
      receiverUserId: receiverUserId ?? this.receiverUserId,
      body: body ?? this.body,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'job_id': jobId,
      'application_id': applicationId,
      'sender_user_id': senderUserId,
      'receiver_user_id': receiverUserId,
      'body': body,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  static JobMessage fromJson(Map<String, dynamic> json) {
    DateTime parseDate(Object? v) {
      if (v is DateTime) return v;
      if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
      return DateTime.now();
    }

    return JobMessage(
      id: (json['id'] ?? '').toString(),
      jobId: (json['job_id'] ?? '').toString(),
      applicationId: (json['application_id'] ?? json['applicationId'])?.toString(),
      senderUserId: (json['sender_user_id'] ?? '').toString(),
      receiverUserId: (json['receiver_user_id'] ?? '').toString(),
      body: (json['body'] ?? '').toString(),
      createdAt: parseDate(json['created_at']),
      updatedAt: parseDate(json['updated_at']),
    );
  }

  static String encodeList(List<JobMessage> items) => jsonEncode(items.map((e) => e.toJson()).toList(growable: false));
  static List<JobMessage> decodeList(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return decoded.whereType<Map>().map((m) => JobMessage.fromJson(m.cast<String, dynamic>())).toList(growable: false);
  }
}
