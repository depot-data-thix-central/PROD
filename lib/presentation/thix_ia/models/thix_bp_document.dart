class ThixBpDocument {
  const ThixBpDocument({
    required this.id,
    required this.projectCode,
    required this.sections,
    this.title,
    this.analysisId,
    this.status = 'draft',
    this.pdfPath,
    this.pdfUrl,
    this.financialSnapshot,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String projectCode;
  final Map<String, dynamic> sections;
  final String? title;
  final String? analysisId;
  final String status;
  final String? pdfPath;
  final String? pdfUrl;
  final Map<String, dynamic>? financialSnapshot;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory ThixBpDocument.fromJson(Map<String, dynamic> json) {
    return ThixBpDocument(
      id: json['id']?.toString() ?? '',
      projectCode: json['project_code']?.toString() ?? '',
      sections: json['sections'] is Map
          ? Map<String, dynamic>.from(json['sections'] as Map)
          : {},
      title: json['title']?.toString(),
      analysisId: json['analysis_id']?.toString(),
      status: json['status']?.toString() ?? 'draft',
      pdfPath: json['pdf_path']?.toString(),
      pdfUrl: json['pdf_url']?.toString(),
      financialSnapshot: json['financial_snapshot'] is Map
          ? Map<String, dynamic>.from(json['financial_snapshot'] as Map)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }

  ThixBpDocument copyWith({
    Map<String, dynamic>? sections,
    String? pdfPath,
    String? pdfUrl,
    String? status,
    DateTime? updatedAt,
  }) {
    return ThixBpDocument(
      id: id,
      projectCode: projectCode,
      sections: sections ?? this.sections,
      title: title,
      analysisId: analysisId,
      status: status ?? this.status,
      pdfPath: pdfPath ?? this.pdfPath,
      pdfUrl: pdfUrl ?? this.pdfUrl,
      financialSnapshot: financialSnapshot,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
