// lib/presentation/education/models/certificate.dart
class Certificate {
  final String id;
  final String? enrollmentId;
  final String userId;
  final String formationId;
  final DateTime issuedAt;
  final String? certificateUrl;
  final String verificationHash;
  final String? serialNumber;
  final String? issuedToName;
  final String? templateId;
  final DateTime? createdAt;

  // Jointures optionnelles
  final String? formationTitle;
  final String? formationImageUrl;

  Certificate({
    required this.id,
    this.enrollmentId,
    required this.userId,
    required this.formationId,
    required this.issuedAt,
    this.certificateUrl,
    required this.verificationHash,
    this.serialNumber,
    this.issuedToName,
    this.templateId,
    this.createdAt,
    this.formationTitle,
    this.formationImageUrl,
  });

  factory Certificate.fromJson(Map<String, dynamic> json) {
    final formation = json['formation'] ?? json['formations'];
    return Certificate(
      id: json['id'] as String,
      enrollmentId: json['enrollment_id'] as String?,
      userId: json['user_id'] as String? ?? '',
      formationId: json['formation_id'] as String? ?? '',
      issuedAt: json['issued_at'] != null
          ? DateTime.parse(json['issued_at'] as String)
          : DateTime.now(),
      certificateUrl: json['certificate_url'] as String?,
      verificationHash: json['verification_hash'] as String? ?? '',
      serialNumber: json['serial_number'] as String?,
      issuedToName: json['issued_to_name'] as String?,
      templateId: json['template_id'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      formationTitle: formation is Map
          ? formation['title'] as String?
          : json['formation_title'] as String?,
      formationImageUrl: formation is Map
          ? formation['image_url'] as String?
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'enrollment_id': enrollmentId,
        'user_id': userId,
        'formation_id': formationId,
        'issued_at': issuedAt.toIso8601String(),
        'certificate_url': certificateUrl,
        'verification_hash': verificationHash,
        'serial_number': serialNumber,
        'issued_to_name': issuedToName,
        'template_id': templateId,
        'created_at': createdAt?.toIso8601String(),
      };
}
