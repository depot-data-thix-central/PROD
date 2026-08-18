import 'dart:convert';

class JobInterview {
  final String id;
  final String jobId;
  final String applicationId;
  final String recruiterUserId;
  final String applicantUserId;
  final DateTime scheduledAt;
  final String mode; // video / phone / onsite
  final String? meetingUrl;
  final String status; // proposed / confirmed / completed / cancelled
  final DateTime createdAt;
  final DateTime updatedAt;

  const JobInterview({
    required this.id,
    required this.jobId,
    required this.applicationId,
    required this.recruiterUserId,
    required this.applicantUserId,
    required this.scheduledAt,
    required this.mode,
    required this.meetingUrl,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  JobInterview copyWith({
    String? id,
    String? jobId,
    String? applicationId,
    String? recruiterUserId,
    String? applicantUserId,
    DateTime? scheduledAt,
    String? mode,
    String? meetingUrl,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return JobInterview(
      id: id ?? this.id,
      jobId: jobId ?? this.jobId,
      applicationId: applicationId ?? this.applicationId,
      recruiterUserId: recruiterUserId ?? this.recruiterUserId,
      applicantUserId: applicantUserId ?? this.applicantUserId,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      mode: mode ?? this.mode,
      meetingUrl: meetingUrl ?? this.meetingUrl,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'job_id': jobId,
      'application_id': applicationId,
      'recruiter_user_id': recruiterUserId,
      'applicant_user_id': applicantUserId,
      'scheduled_at': scheduledAt.toUtc().toIso8601String(),
      'mode': mode,
      'meeting_url': meetingUrl,
      'status': status,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  static JobInterview fromJson(Map<String, dynamic> json) {
    DateTime parseDate(Object? v) {
      if (v is DateTime) return v;
      if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
      return DateTime.now();
    }

    return JobInterview(
      id: (json['id'] ?? '').toString(),
      jobId: (json['job_id'] ?? '').toString(),
      applicationId: (json['application_id'] ?? '').toString(),
      recruiterUserId: (json['recruiter_user_id'] ?? '').toString(),
      applicantUserId: (json['applicant_user_id'] ?? '').toString(),
      scheduledAt: parseDate(json['scheduled_at']),
      mode: (json['mode'] ?? 'video').toString(),
      meetingUrl: (json['meeting_url'] ?? json['meetingUrl'])?.toString(),
      status: (json['status'] ?? 'proposed').toString(),
      createdAt: parseDate(json['created_at']),
      updatedAt: parseDate(json['updated_at']),
    );
  }

  static String encodeList(List<JobInterview> items) => jsonEncode(items.map((e) => e.toJson()).toList(growable: false));
  static List<JobInterview> decodeList(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return decoded.whereType<Map>().map((m) => JobInterview.fromJson(m.cast<String, dynamic>())).toList(growable: false);
  }
}
