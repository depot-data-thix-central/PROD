import 'dart:convert';

class JobPosting {
  final String id;
  /// Recruiter/company owner user id (Supabase auth uid) when available.
  final String? recruiterUserId;

  /// Company id (recommended) when available.
  final String? companyId;

  final String title;
  /// Display name (fallback when companyId not used).
  final String company;

  /// Optional company logo url.
  final String? companyLogoUrl;

  /// Whether employer/company is verified.
  final bool isVerifiedEmployer;

  final String location;

  /// Human-readable label (ex: "$2,000 - $3,000").
  final String salary;

  /// Structured salary range (optional).
  final int? salaryMin;
  final int? salaryMax;
  final String? salaryCurrency;

  /// Contract type (full_time/part_time/contract...).
  final String type;

  /// Work mode (remote/hybrid/on_site).
  final String? workMode;

  /// Category/segment (internship/freelance/startup/government/ngo...).
  final String? category;

  final String? industry;
  final String? experienceLevel;

  final String description;
  final List<String> requirements;

  final List<String> skills;
  final List<String> responsibilities;
  final List<String> benefits;

  final DateTime? deadline;

  /// Current moderation status (pending/approved/rejected).
  final String? status;

  final int? applicantsCount;
  final bool isFeatured;
  /// Whether the offer should appear in the "Suggestions pour vous" carousel.
  final bool isSuggested;

  final DateTime createdAt;
  final DateTime updatedAt;

  const JobPosting({
    required this.id,
    required this.recruiterUserId,
    required this.companyId,
    required this.title,
    required this.company,
    required this.companyLogoUrl,
    required this.isVerifiedEmployer,
    required this.location,
    required this.salary,
    required this.salaryMin,
    required this.salaryMax,
    required this.salaryCurrency,
    required this.type,
    required this.workMode,
    required this.category,
    required this.industry,
    required this.experienceLevel,
    required this.description,
    required this.requirements,
    required this.skills,
    required this.responsibilities,
    required this.benefits,
    required this.deadline,
    required this.status,
    required this.applicantsCount,
    required this.isFeatured,
    required this.isSuggested,
    required this.createdAt,
    required this.updatedAt,
  });

  JobPosting copyWith({
    String? id,
    String? recruiterUserId,
    String? companyId,
    String? title,
    String? company,
    String? companyLogoUrl,
    bool? isVerifiedEmployer,
    String? location,
    String? salary,
    int? salaryMin,
    int? salaryMax,
    String? salaryCurrency,
    String? type,
    String? workMode,
    String? category,
    String? industry,
    String? experienceLevel,
    String? description,
    List<String>? requirements,
    List<String>? skills,
    List<String>? responsibilities,
    List<String>? benefits,
    DateTime? deadline,
    String? status,
    int? applicantsCount,
    bool? isFeatured,
    bool? isSuggested,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return JobPosting(
      id: id ?? this.id,
      recruiterUserId: recruiterUserId ?? this.recruiterUserId,
      companyId: companyId ?? this.companyId,
      title: title ?? this.title,
      company: company ?? this.company,
      companyLogoUrl: companyLogoUrl ?? this.companyLogoUrl,
      isVerifiedEmployer: isVerifiedEmployer ?? this.isVerifiedEmployer,
      location: location ?? this.location,
      salary: salary ?? this.salary,
      salaryMin: salaryMin ?? this.salaryMin,
      salaryMax: salaryMax ?? this.salaryMax,
      salaryCurrency: salaryCurrency ?? this.salaryCurrency,
      type: type ?? this.type,
      workMode: workMode ?? this.workMode,
      category: category ?? this.category,
      industry: industry ?? this.industry,
      experienceLevel: experienceLevel ?? this.experienceLevel,
      description: description ?? this.description,
      requirements: requirements ?? this.requirements,
      skills: skills ?? this.skills,
      responsibilities: responsibilities ?? this.responsibilities,
      benefits: benefits ?? this.benefits,
      deadline: deadline ?? this.deadline,
      status: status ?? this.status,
      applicantsCount: applicantsCount ?? this.applicantsCount,
      isFeatured: isFeatured ?? this.isFeatured,
      isSuggested: isSuggested ?? this.isSuggested,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'recruiter_user_id': recruiterUserId,
      'company_id': companyId,
      'title': title,
      'company': company,
      'company_logo_url': companyLogoUrl,
      'is_verified_employer': isVerifiedEmployer,
      'location': location,
      'salary': salary,
      'salary_min': salaryMin,
      'salary_max': salaryMax,
      'salary_currency': salaryCurrency,
      'type': type,
      'work_mode': workMode,
      'category': category,
      'industry': industry,
      'experience_level': experienceLevel,
      'description': description,
      'requirements': requirements,
      'skills': skills,
      'responsibilities': responsibilities,
      'benefits': benefits,
      'deadline': deadline?.toIso8601String(),
      'status': status,
      'applicants_count': applicantsCount,
      'is_featured': isFeatured,
      'is_suggested': isSuggested,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  static JobPosting fromJson(Map<String, dynamic> json) {
    DateTime parseDate(Object? v) {
      if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
      return DateTime.now();
    }

    int? parseInt(Object? v) {
      if (v == null) return null;
      if (v is int) return v;
      return int.tryParse(v.toString());
    }

    bool parseBool(Object? v) {
      if (v is bool) return v;
      final s = (v ?? '').toString().trim().toLowerCase();
      return s == '1' || s == 'true' || s == 'yes';
    }

    List<String> parseList(Object? v) {
      if (v is List) {
        return v.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList(growable: false);
      }
      if (v is String) {
        // best effort: comma separated
        final parts = v.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(growable: false);
        return parts;
      }
      return const <String>[];
    }

    DateTime? parseNullableDate(Object? v) {
      if (v == null) return null;
      if (v is DateTime) return v;
      if (v is String) return DateTime.tryParse(v);
      return DateTime.tryParse(v.toString());
    }

    return JobPosting(
      id: (json['id'] ?? '').toString(),
      recruiterUserId: (json['recruiter_user_id'] ?? json['recruiterUserId'])?.toString(),
      companyId: (json['company_id'] ?? json['companyId'])?.toString(),
      title: (json['title'] ?? '').toString(),
      company: (json['company'] ?? '').toString(),
      companyLogoUrl: (json['company_logo_url'] ?? json['companyLogoUrl'])?.toString(),
      isVerifiedEmployer: parseBool(json['is_verified_employer'] ?? json['isVerifiedEmployer'] ?? false),
      location: (json['location'] ?? '').toString(),
      salary: (json['salary'] ?? '').toString(),
      salaryMin: parseInt(json['salary_min'] ?? json['salaryMin']),
      salaryMax: parseInt(json['salary_max'] ?? json['salaryMax']),
      salaryCurrency: (json['salary_currency'] ?? json['salaryCurrency'])?.toString(),
      type: (json['type'] ?? '').toString(),
      workMode: (json['work_mode'] ?? json['workMode'])?.toString(),
      category: (json['category'] ?? '').toString().trim().isEmpty ? null : (json['category'] ?? '').toString(),
      industry: (json['industry'] ?? '').toString().trim().isEmpty ? null : (json['industry'] ?? '').toString(),
      experienceLevel: (json['experience_level'] ?? json['experienceLevel'])?.toString(),
      description: (json['description'] ?? '').toString(),
      requirements: parseList(json['requirements']),
      skills: parseList(json['skills']),
      responsibilities: parseList(json['responsibilities']),
      benefits: parseList(json['benefits']),
      deadline: parseNullableDate(json['deadline']),
      status: (json['status'] ?? '').toString().trim().isEmpty ? null : (json['status'] ?? '').toString(),
      applicantsCount: parseInt(json['applicants_count'] ?? json['applicantsCount']),
      isFeatured: parseBool(json['is_featured'] ?? json['isFeatured'] ?? false),
      isSuggested: parseBool(json['is_suggested'] ?? json['isSuggested'] ?? false),
      createdAt: parseDate(json['created_at']),
      updatedAt: parseDate(json['updated_at']),
    );
  }

  static String encodeList(List<JobPosting> items) => jsonEncode(items.map((e) => e.toJson()).toList(growable: false));

  static List<JobPosting> decodeList(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return decoded.whereType<Map>().map((m) => JobPosting.fromJson(m.cast<String, dynamic>())).toList(growable: false);
  }
}
