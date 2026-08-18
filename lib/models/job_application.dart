import 'dart:convert';

class JobApplication {
  final String id;
  final String jobId;
  final String applicantThixId;

  /// Supabase auth uid of applicant when available.
  final String? applicantUserId;

  final String? message;

  /// applied / shortlisted / interview / rejected / hired
  final String status;

  /// Attachments (optional)
  final String? portfolioUrl;
  final String? videoIntroUrl;
  final String? resumeUrl;
  final List<String> diplomaUrls;

  /// Recruiter notes (server-side)
  final String? recruiterNote;

  final DateTime createdAt;
  final DateTime updatedAt;

  const JobApplication({
    required this.id,
    required this.jobId,
    required this.applicantThixId,
    required this.applicantUserId,
    required this.message,
    required this.status,
    required this.portfolioUrl,
    required this.videoIntroUrl,
    required this.resumeUrl,
    required this.diplomaUrls,
    required this.recruiterNote,
    required this.createdAt,
    required this.updatedAt,
  });

  JobApplication copyWith({
    String? id,
    String? jobId,
    String? applicantThixId,
    String? applicantUserId,
    String? message,
    String? status,
    String? portfolioUrl,
    String? videoIntroUrl,
    String? resumeUrl,
    List<String>? diplomaUrls,
    String? recruiterNote,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return JobApplication(
      id: id ?? this.id,
      jobId: jobId ?? this.jobId,
      applicantThixId: applicantThixId ?? this.applicantThixId,
      applicantUserId: applicantUserId ?? this.applicantUserId,
      message: message ?? this.message,
      status: status ?? this.status,
      portfolioUrl: portfolioUrl ?? this.portfolioUrl,
      videoIntroUrl: videoIntroUrl ?? this.videoIntroUrl,
      resumeUrl: resumeUrl ?? this.resumeUrl,
      diplomaUrls: diplomaUrls ?? this.diplomaUrls,
      recruiterNote: recruiterNote ?? this.recruiterNote,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'job_id': jobId,
      'applicant_thix_id': applicantThixId,
      'applicant_user_id': applicantUserId,
      'message': message,
      'status': status,
      'portfolio_url': portfolioUrl,
      'video_intro_url': videoIntroUrl,
      'resume_url': resumeUrl,
      'diploma_urls': diplomaUrls,
      'recruiter_note': recruiterNote,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  static JobApplication fromJson(Map<String, dynamic> json) {
    DateTime parseDate(Object? v) {
      if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
      return DateTime.now();
    }

    List<String> parseList(Object? v) {
      if (v is List) {
        return v.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList(growable: false);
      }
      if (v is String) {
        final parts = v.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(growable: false);
        return parts;
      }
      return const <String>[];
    }

    return JobApplication(
      id: (json['id'] ?? '').toString(),
      jobId: (json['job_id'] ?? '').toString(),
      applicantThixId: (json['applicant_thix_id'] ?? '').toString(),
      applicantUserId: (json['applicant_user_id'] ?? json['applicantUserId'])?.toString(),
      message: (json['message'] ?? '').toString().trim().isEmpty ? null : (json['message'] ?? '').toString(),
      status: (json['status'] ?? '').toString().trim().isEmpty ? 'applied' : (json['status'] ?? '').toString(),
      portfolioUrl: (json['portfolio_url'] ?? json['portfolioUrl'])?.toString(),
      videoIntroUrl: (json['video_intro_url'] ?? json['videoIntroUrl'])?.toString(),
      resumeUrl: (json['resume_url'] ?? json['resumeUrl'])?.toString(),
      diplomaUrls: parseList(json['diploma_urls'] ?? json['diplomaUrls']),
      recruiterNote: (json['recruiter_note'] ?? json['recruiterNote'])?.toString(),
      createdAt: parseDate(json['created_at']),
      updatedAt: parseDate(json['updated_at']),
    );
  }

  static String encodeList(List<JobApplication> items) => jsonEncode(items.map((e) => e.toJson()).toList(growable: false));

  static List<JobApplication> decodeList(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return decoded.whereType<Map>().map((m) => JobApplication.fromJson(m.cast<String, dynamic>())).toList(growable: false);
  }
}
